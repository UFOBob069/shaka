# frozen_string_literal: true

require 'optparse'
require_relative '../call_log'

module Shaka
  module Evidence
    # Parses the local evidence operations without repeating result logic.
    module Options
      private

      def action!
        action = @arguments.shift
        return action if %w[run bind verify guard].include?(action)

        raise OptionParser::InvalidArgument, 'Usage: shaka evidence (run|bind|verify|guard) [options]'
      end

      def parser(action)
        OptionParser.new do |flags|
          suffix = { 'run' => '--command NAME [-- ARGS]', 'bind' => '--result PATH --head SHA',
                     'verify' => '--head SHA --validation PATH --review PATH',
                     'guard' => '--base REF --head SHA [--flow feature|setup|migration]' }.fetch(action)
          flags.banner = "Usage: shaka evidence #{action} --root DIR --ref SHA --repository OWNER/REPO #{suffix}"
          add_value_flags(flags)
          flags.on('-h', '--help') { @options[:help] = true }
        end
      end

      def add_value_flags(flags)
        %w[root ref repository command result head base flow].each do |name|
          flags.on("--#{name} VALUE") { |value| CallLog.tag(name => @options[name.to_sym] = value) }
        end
        %w[validation review].each do |name|
          flags.on("--#{name} PATH") { |value| (@options[name.to_sym] ||= []) << value }
        end
      end
    end
  end
end
