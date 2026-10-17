# frozen_string_literal: true

require 'optparse'
require_relative 'error'
require_relative 'configuration'
require_relative 'pr_template'

module Shaka
  # Prints one repository guidance file from the selected settings source, never the candidate branch.
  class Guidance
    NAMES = RepositoryConfig::ProjectGuidanceSchema::NAMES
    USAGE = "Usage: shaka guidance #{NAMES.join('|')} [--root DIR] [--ref REF]".freeze

    def self.run(arguments)
      options = parse(arguments)
      return 0 unless options

      print new(**options).call
      0
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def self.parse(arguments)
      options = {}
      parser = option_parser(options)
      parser.parse!(arguments)
      return puts(parser) if options[:help]
      raise OptionParser::InvalidArgument, USAGE unless arguments.size == 1 && NAMES.include?(arguments.first)

      { name: arguments.first, root: File.realpath(options.fetch(:root, Dir.pwd)), ref: options[:ref] }
    end

    def self.option_parser(options)
      OptionParser.new do |flags|
        flags.banner = USAGE
        flags.on('--root DIR', 'Repository root (default: current directory)') { |value| options[:root] = value }
        flags.on('--ref REF', 'Trusted Git commit or ref (default: origin/HEAD, then origin/main)') do |value|
          options[:ref] = value
        end
        flags.on('-h', '--help', 'Show usage') { options[:help] = true }
      end
    end

    private_class_method :parse, :option_parser

    def initialize(name:, root:, ref: nil)
      @name = name
      @root = root
      @ref = ref
    end

    def call
      ref = @ref || Configuration.default_ref(root: @root)
      sha = Configuration.resolve_commit(root: @root, ref:, label: 'guidance ref')
      config = Configuration.resolve_source(root: @root, ref: sha, candidate_commands: false).first
      label = "#{RepositoryConfig::ProjectGuidanceSchema::KEY}.#{@name}"
      path = config.project_guidance[@name]
      raise Error, "#{label} is not configured" unless path

      text = Configuration.configured_prompt(root: @root, config:, ref: sha, path:, label:)
      @name == 'pr_evidence' ? with_template(text, path, config.sha || sha) : text
    end

    private

    # PR evidence also carries the repository's pull request template, read from the same trusted commit.
    # A guide that names a template is the template; a broken template is skipped so the guide still prints.
    def with_template(text, guide_path, sha)
      template = PrTemplate.path(root: @root, sha:)
      return text if template.nil? || PrTemplate::PATHS.include?(guide_path)

      body = TrustedConfigSource.new(root: @root).read_prompt(template, sha, 'pull request template')
      "#{text.chomp}\n\n---\n\nPull request template (#{template}):\n\n#{body}"
    rescue Error => e
      "#{text.chomp}\n\n---\n\nPull request template skipped: #{e.message}\n"
    end
  end
end
