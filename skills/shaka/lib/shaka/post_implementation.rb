# frozen_string_literal: true

require 'optparse'
require_relative 'post_implementation_runner'
require_relative 'post_implementation/history'
require_relative 'post_implementation/publication'
require_relative 'post_implementation/disposition'
require_relative 'github'
require_relative 'handoff/walkthrough'
require_relative 'publication/squash_message'

module Shaka
  # Runs and publishes one product checkpoint on the existing PR.
  class PostImplementation
    KEY = 'post-implementation'

    def self.run(arguments, github: nil)
      new(arguments, github:).run
    rescue OptionParser::ParseError, SystemCallError, JSON::ParserError, KeyError, TypeError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments, github: nil)
      @arguments = arguments.dup
      @options = {}
      @github = github
    end

    def run
      action = @arguments.shift
      raise Error, 'Usage: shaka post-implementation (run|publish) [options]' unless %w[run publish].include?(action)

      flags = parser(action)
      flags.parse!(@arguments)
      return 0.tap { puts flags } if @options[:help]

      raise Error, '--content-file is required' if action == 'publish' && !@options[:content_file]

      present(action == 'run' ? execute : publish, action)
    end

    def present(result, action)
      puts JSON.pretty_generate(result)
      return 1 if result.dig('earlier_checkpoints', 'unavailable')&.any?

      %w[completed opted_out].include?(result['status']) || action == 'publish' ? 0 : 1
    end

    private

    def execute
      raise Error, 'run takes no positional arguments' unless @arguments.empty?

      %i[root base head criteria_ref].each { |key| raise Error, "Missing #{key}" unless @options[key] }
      PostImplementationRunner.new(@options).run
    end

    def publish
      raise Error, 'publish needs OWNER/REPO NUMBER' unless @arguments.size == 2

      result = publication_result
      github = @github || GitHub.new(*@arguments)
      head = result.fetch('head')
      live = github.snapshot.values_at('state', 'headRefOid')
      raise Error, 'Checkpoint is not for the live open PR head' unless live == ['OPEN', head]

      published = publish_body(github, result, head)
      published.merge('earlier_checkpoints' => PostImplementationHistory.new(github).collapse(published))
    end

    def publish_body(github, result, head)
      renderer = result.key?('disposition') ? PostImplementationDispositionPublication : PostImplementationPublication
      message = -> { ready_message(github, head) }
      body = renderer.new(result, head:, repository: @arguments.first, message:).render
      github.reply(body:, key: "#{KEY}-#{head[0, 7]}-#{result.fetch('execution_id')}")
    end

    # A ready checkpoint closes the PR's reports, so the walkthrough it follows has to be there already.
    def ready_message(github, head)
      unless Handoff::Walkthrough.new(github).revision == head
        raise Error, "Ready checkpoint follows this account's walkthrough for #{head}; publish the walkthrough first."
      end

      squash_message(github)
    end

    def squash_message(github)
      path = @options[:squash_message]
      unless path
        raise Error,
              'Ready checkpoint requires --squash-message with the commit title and body.'
      end

      SquashMessage.for(github, JSON.parse(File.read(path, encoding: 'UTF-8')))
    end

    def publication_result
      result = JSON.parse(File.read(@options.fetch(:content_file), encoding: 'UTF-8'))
      raise Error, 'Checkpoint result must be an object' unless result.is_a?(Hash)
      raise Error, 'Not a product checkpoint result' unless result['purpose'] == 'post_implementation'
      raise Error, 'Checkpoint has no execution identity' unless
        result['execution_id'].to_s.match?(/\A[0-9a-f]{8}\z/)

      result
    end

    def parser(action)
      OptionParser.new do |flags|
        flags.banner = "Usage: shaka post-implementation #{action} [options]"
        %w[root base head reviewer model effort prompt-file content-file squash-message timeout-seconds
           opt-out].each do |key|
          flags.on("--#{key} VALUE") { |value| @options[key.tr('-', '_').to_sym] = value }
        end
        flags.on('--ref SHA') { |value| @options[:criteria_ref] = value }
        flags.on('-h', '--help') { @options[:help] = true }
      end
    end
  end
end
