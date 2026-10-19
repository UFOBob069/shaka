# frozen_string_literal: true

module Shaka
  class Doctor
    # Parses doctor options before any optional billable launch.
    module Command
      def option_parser(options)
        OptionParser.new do |flags|
          flags.banner = 'Usage: shaka doctor [--root DIR] [--host NAME] [--probe-reviewers] [--installation-json]'
          flags.on('--root DIR', 'Repository root (default: current directory)') { |value| options[:root] = value }
          flags.on('--host NAME', Usage::READERS.keys, Usage::READERS.keys.join(', ')) do |value|
            options[:host] = value
          end
          probe_flags(flags, options)
          flags.on('--installation-json', 'JSON installation identity') { options[:installation_json] = true }
          flags.on('-h', '--help', 'Show usage') { options[:help] = true }
        end
      end

      def probe_flags(flags, options)
        flags.on('--ref SHA', 'Verified default-branch commit for billable probes') { |value| options[:ref] = value }
        flags.on('--probe-reviewers', 'Launch each configured reviewer once; may consume quota or incur cost') do
          options[:probe_reviewers] = true
        end
        flags.on('--probe-timeout-seconds N', Integer, 'Probe deadline per reviewer, 1..120s (default: 30)') do |value|
          options[:probe_timeout] = value
        end
      end

      def validate_probe_options!(options)
        validate_probe_ref!(options)
        return unless options.key?(:probe_timeout) || options[:ref]

        unless options[:probe_reviewers]
          flag = options.key?(:probe_timeout) ? '--probe-timeout-seconds' : '--ref'
          raise OptionParser::InvalidArgument, "#{flag} requires --probe-reviewers"
        end
        return unless options.key?(:probe_timeout)

        raise OptionParser::InvalidArgument, '--probe-timeout-seconds must be 1..120' unless
          (1..120).cover?(options[:probe_timeout])
      end

      def validate_probe_ref!(options)
        return unless options[:probe_reviewers]
        return if options[:ref].to_s.match?(/\A[0-9a-f]{40}(?:[0-9a-f]{24})?\z/)

        raise OptionParser::InvalidArgument, '--probe-reviewers requires --ref with a verified default-branch SHA'
      end

      def probe_options(options)
        options.slice(:ref).merge(timeout: options.fetch(:probe_timeout, 30)) if options[:probe_reviewers]
      end

      private :option_parser, :probe_flags, :validate_probe_options!, :validate_probe_ref!, :probe_options
    end
  end
end
