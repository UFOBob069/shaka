# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'call_log'
require_relative 'error'
require_relative 'github'
require_relative 'local_review/publisher'
require_relative 'local_review/history'
require_relative 'local_review/ledger'
require_relative 'local_review/runner'
require_relative 'local_review/report_check'
require_relative 'evidence/review'

module Shaka
  # Entry point for process-verified reviews and explicitly weaker host reports.
  class LocalReview
    def self.run(arguments, github: nil)
      return LocalReviewHistory.run(arguments.drop(1), github:) if arguments.first == 'collapse'

      new(arguments, github:).run
    rescue OptionParser::ParseError, SystemCallError, JSON::ParserError, Shaka::Error => e
      warn "shaka: #{e.message}"
      1
    end

    def initialize(arguments, github: nil)
      @arguments = arguments.dup
      @options = {}
      @github = github
    end

    ACTIONS = %w[run check record assess publish collapse].freeze

    def run
      action = @arguments.shift
      raise OptionParser::InvalidArgument, "Usage: shaka review (#{ACTIONS.join('|')}) [options]" unless
        ACTIONS.include?(action)

      parser = send(:"#{action}_parser")
      parser.parse!(@arguments)
      return 0.tap { puts parser } if @options[:help]
      return send(action, parser) if %w[record assess publish].include?(action)

      raise OptionParser::InvalidArgument, parser.to_s unless @arguments.empty?

      present(dispatch(action))
    end

    private

    def present(result)
      puts JSON.pretty_generate(result)
      %w[completed reported].include?(result.fetch('status')) ? 0 : 1
    end

    def run_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review run --root DIR --base SHA --head SHA --reviewer ID'
        %w[root base head reviewer effort model criteria-ref settings-ref repository description-file timeout-seconds
           ledger max-review-executions budget-reason].each do |key|
          flags.on("--#{key} VALUE") { |value| CallLog.tag(key => @options[key.tr('-', '_').to_sym] = value) }
        end
        flags.on('-h', '--help') { @options[:help] = true }
      end
    end

    def dispatch(action)
      original_path = ENV.fetch('PATH', nil)
      evidence = Evidence::Review.start(@options, action:)
      result = action == 'run' ? LocalReviewRunner.new(@options).run : LocalReviewReportCheck.new(@options).run
      evidence ? evidence.finish(result) : result
    ensure
      ENV['PATH'] = original_path
    end

    # `merge` decides whether the attested commit covers the PR head, so publishing does not.
    def publish(parser)
      raise OptionParser::InvalidArgument, parser.to_s unless @arguments.length == 2 && @options[:content_file]

      github = @github || GitHub.new(*@arguments)
      result = LocalReviewPublisher.new(published_content, github, @arguments.first).publish
      puts JSON.pretty_generate(result)
      result.fetch('cleanup').fetch('unavailable').empty? ? 0 : 1
    end

    def record(parser)
      raise OptionParser::InvalidArgument, parser.to_s unless
        @arguments.empty? && @options[:ledger] && @options[:content_file]

      recorded = LocalReviewLedger.new(@options[:ledger]).record!(content, head: @options[:head])
      puts JSON.pretty_generate('ledger' => File.expand_path(@options[:ledger]), 'rounds' => recorded)
      0
    end

    def assess(parser)
      raise OptionParser::InvalidArgument, parser.to_s unless
        @arguments.empty? && @options[:ledger] && @options[:content_file] && !@options[:head]

      id = LocalReviewLedger.new(@options[:ledger]).assess!(content)
      puts JSON.pretty_generate('ledger' => File.expand_path(@options[:ledger]), 'assessment' => id)
      0
    end

    def assess_parser
      record_parser.tap { |parser| parser.banner = 'Usage: shaka review assess --ledger PATH --content-file PATH' }
    end

    def record_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review record --ledger PATH --content-file PATH'
        flags.on('--ledger PATH') { |value| @options[:ledger] = value }
        flags.on('--head SHA', /\A[0-9a-f]{40}\z/) { |value| CallLog.tag(head: @options[:head] = value) }
        flags.on('--content-file PATH') { |value| @options[:content_file] = value }
        flags.on('-h', '--help') { @options[:help] = true }
      end
    end

    def content = JSON.parse(File.read(@options[:content_file], encoding: 'UTF-8'))

    # Finds each kept report, including beside a ledger that has moved, or names the one that is gone.
    def published_content
      LocalReviewBundle.resolve(content, File.dirname(File.expand_path(@options[:content_file])))
    end

    def publish_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review publish OWNER/REPO NUMBER --content-file PATH'
        flags.on('--content-file PATH') { |value| @options[:content_file] = value }
        flags.on('-h', '--help') { @options[:help] = true }
      end
    end

    def check_parser
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review check --head SHA (--reviewer ID --report PATH | --not-run-reason TEXT)'
        %w[head reviewer report not-run-reason root settings-ref repository].each do |key|
          flags.on("--#{key} VALUE") { |value| CallLog.tag(key => @options[key.tr('-', '_').to_sym] = value) }
        end
        flags.on('-h', '--help') { @options[:help] = true }
      end
    end
  end
end
