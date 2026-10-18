# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'prepare'
require_relative 'report'

module Shaka
  module Trial
    # Preparation is local; report is the explicit authorization to publish field feedback.
    module Command
      ACTIONS = %w[prepare report].freeze
      ERRORS = [Error, ArgumentError, SystemCallError, OptionParser::ParseError,
                JSON::ParserError, URI::InvalidURIError].freeze

      def self.run(arguments)
        action = arguments.shift
        options, parser = options(arguments, action)
        return print_help(parser) if options[:help]
        raise OptionParser::InvalidArgument, parser.to_s unless arguments.one? && ACTIONS.include?(action)

        result = execute(action, arguments.first, options)
        puts JSON.pretty_generate(result)
        0
      rescue *ERRORS => e
        warn "shaka trial: #{e.message}"
        1
      end

      def self.options(arguments, action)
        options = { root: Dir.pwd, directory: File.join(Dir.home, '.local/share/shaka/pr-trials'),
                    help: %w[-h --help].include?(action) }
        parser = parser(options, action)
        parser.parse!(arguments)
        [options, parser]
      end

      def self.parser(options, action)
        OptionParser.new do |flags|
          flags.banner = 'Usage: shaka trial prepare|report SHAKA_PR_URL [options]'
          prepare_flags(flags, options) if action == 'prepare'
          if action == 'report'
            flags.on('--content-file PATH', 'Public-safe report JSON') do |v|
              options[:content_file] = v
            end
          end
          flags.on('-h', '--help') { options[:help] = true }
        end
      end

      def self.prepare_flags(flags, options)
        flags.on('--root PATH', 'Target project for a new trial') { |v| options[:root] = v }
        flags.on('--directory PATH', 'Trial storage outside project checkouts') { |v| options[:directory] = v }
        flags.on('--task TEXT', 'Task included in the fresh-session prompt') { |v| options[:task] = v }
      end

      def self.execute(action, url, options)
        return Prepare.new(url, **options.slice(:root, :directory, :task)).run if action == 'prepare'
        raise Error, 'Supply --content-file PATH for the report.' unless options[:content_file]

        Report.new(url, JSON.parse(File.read(options[:content_file]))).run
      end

      def self.print_help(parser)
        puts parser
        0
      end
    end
  end
end
