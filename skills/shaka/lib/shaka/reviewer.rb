# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'error'
require_relative 'repository_config'
require_relative 'reviewer_selection'
require_relative 'review_coverage'
require_relative 'configuration'
require_relative 'doctor/cli_inventory'

module Shaka
  # Answers which listed reviewers satisfy the alternate-review gate for one change.
  class Reviewer
    def self.run(arguments)
      new(arguments).run
    rescue OptionParser::ParseError, SystemCallError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments)
      @arguments = arguments.dup
      @options = {}
    end

    def run
      parser = option_parser
      parser.parse!(@arguments)
      return help(parser) if @options[:help]
      raise OptionParser::InvalidArgument, parser.to_s unless @arguments.empty?

      puts JSON.pretty_generate(selection)
      0
    end

    private

    def selection
      review = config.review
      inventory = Doctor::CliInventory.new(root:, environment: ENV).call(review)
      unavailable = identities(:unavailable)
      not_set_up = Doctor::CliInventory.not_set_up(inventory)
      result = ReviewerSelection.new(reviewers: candidates(review, unavailable + not_set_up),
                                     implementers: identities(:implementers, required: true),
                                     unavailable:, not_set_up:, count: count(review)).call
      result.merge('provider_coverage' => coverage(review, result),
                   'setup_notices' => Doctor::CliInventory.setup_notices(inventory))
    end

    # A task's --count wins unless coverage sets one reviewer per listed provider.
    def count(review)
      return ReviewCoverage.count(review) unless @options.key?(:count)
      raise OptionParser::InvalidArgument, "--count does not apply while review.#{ReviewCoverage::KEY} is set" unless
        ReviewCoverage.names(covered(review)).empty?

      @options[:count]
    end

    def candidates(review, skipped)
      entries = review[RepositoryConfig::ReviewSchema::LOCAL_REVIEW_AGENTS] || []
      usable = ->(entry) { skipped.none? { |other| key(other) == key(entry) } }
      ReviewCoverage.candidates(entries, covered(review), usable)
    end

    def key(entry) = entry.values_at('provider', 'model_family').map(&:downcase)

    def coverage(review, selection) = ReviewCoverage.coverage(covered(review), selection)

    def covered(review) = ReviewCoverage.setting(review, ReviewCoverage::KEY)

    def identities(key, required: false)
      values = @options.fetch(key, [])
      raise OptionParser::MissingArgument, '--implementer is required' if required && values.empty?

      values.map { |value| ReviewerSelection.parse(value) }
    end

    def config
      return Configuration.worktree(root:) unless @options[:ref]

      Configuration.resolve_source(root:, ref: @options[:ref]).first
    end

    def option_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka reviewer --implementer PROVIDER/FAMILY [options]'
        flags.on('--root DIR', 'Repository root (default: current directory)') { |v| @options[:root] = v }
        flags.on('--ref REF', 'Read policy from this trusted Git commit') { |v| @options[:ref] = v }
        add_identity_options(flags)
        flags.on('--count N', Integer, 'Reviewers to run on the same head (default: 1)') { |v| @options[:count] = v }
        flags.on('-h', '--help', 'Show usage') { @options[:help] = true }
      end
    end

    def add_identity_options(flags)
      flags.on('--implementer ID', 'PROVIDER/FAMILY that produced part of the change; repeatable') do |v|
        (@options[:implementers] ||= []) << v
      end
      flags.on('--unavailable ID', 'PROVIDER/FAMILY shown unavailable on evidence; repeatable') do |v|
        (@options[:unavailable] ||= []) << v
      end
    end

    def help(parser)
      puts parser
      0
    end

    def root = File.realpath(@options.fetch(:root, Dir.pwd))
  end
end
