# frozen_string_literal: true

require_relative '../configuration/settings_preview'

module Shaka
  class Seam
    # Selecting a preview is an explicit local action, separate from checking policy.
    class PreviewCommand
      def self.run(arguments) = new(arguments).run

      def initialize(arguments)
        @arguments = arguments.dup
        @options = { root: Dir.pwd }
      end

      def run
        parser = option_parser
        parser.parse!(@arguments)
        operation = @arguments.shift
        validate_operation(operation, parser)
        preview = Configuration::SettingsPreview.new(root: @options[:root])
        result = operation == 'start' ? preview.start(@options[:ref]) : preview.public_send(operation)
        puts JSON.pretty_generate(result)
        0
      end

      private

      def option_parser
        OptionParser.new do |flags|
          flags.banner = 'Usage: shaka seam preview start|stop|status --root DIR [--settings-ref SHA]'
          flags.on('--root DIR') { |value| @options[:root] = value }
          flags.on('--settings-ref SHA') { |value| @options[:ref] = value }
        end
      end

      def validate_operation(operation, parser)
        raise OptionParser::InvalidArgument, parser.to_s unless
          @arguments.empty? && %w[start stop status].include?(operation)
        raise OptionParser::InvalidArgument, '--settings-ref is only for start' if
          operation != 'start' && @options[:ref]
      end
    end
  end
end
