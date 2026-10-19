# frozen_string_literal: true

require 'json'

module Shaka
  class Doctor
    # Reads user-level Cursor hooks.json for the stop-hook command; never reads usage payloads.
    class CursorStopHook
      NAME = 'cursor-usage-hook'
      HOOKS = '~/.cursor/hooks.json'
      EXTENSION = /\.(?:cmd|bat|exe)\z/i
      RUBY = /\Aruby(?:\.exe)?\z/i

      def self.installed?(path = nil)
        new(path || File.expand_path(HOOKS)).installed?
      rescue ArgumentError
        false
      end

      def initialize(path)
        @path = path
      end

      def installed?
        commands.any? { |command| hook_command?(command) }
      rescue SystemCallError, JSON::ParserError
        false
      end

      private

      def commands
        parsed = JSON.parse(File.read(@path, encoding: 'UTF-8'))
        hooks = parsed['hooks'] if parsed.is_a?(Hash)
        stop = hooks['stop'] if hooks.is_a?(Hash)
        Array(stop).filter_map { |entry| command_text(entry) }
      end

      def command_text(entry)
        value = entry['command'] if entry.is_a?(Hash)
        value if value.is_a?(String)
      end

      def hook_command?(command)
        tokens = command_tokens(command)
        return false if tokens.empty?
        return true if hook_name?(tokens.first)
        return false unless ruby?(tokens.first)

        tokens.drop(1).any? { |token| hook_name?(token) }
      rescue ArgumentError
        false
      end

      def command_tokens(command)
        command.scan(/"([^"]*)"|'([^']*)'|(\S+)/).map { |quoted, single, bare| quoted || single || bare }
      end

      def ruby?(token)
        File.basename(token).match?(RUBY)
      end

      # Windows runs the `.cmd` launcher. Its basename is the hook name without that extension.
      def hook_name?(token)
        File.basename(token).sub(EXTENSION, '') == NAME
      end
    end
  end
end
