# frozen_string_literal: true

require 'json'

module Shaka
  module Install
    # Reads the installation record kept under the checkout's `.git` directory.
    module CheckoutRecord
      # Another account must not be able to replace the checkout or its record.
      def verify_directories
        verify_safe_directory(@root, 'Installation directory')
        refuse_linked_worktree
        verify_safe_directory(File.join(@root, '.git'), 'Installation Git directory')
      end

      def read_record
        path = File.join(@root, '.git', Checkout::RECORD)
        return unless File.exist?(path) || File.symlink?(path)

        raise ArgumentError, 'Installation record must be a regular file' unless File.lstat(path).file?

        value = JSON.parse(File.read(path))
        raise ArgumentError, 'Installation record does not match this directory' unless
          valid_record?(value)

        value
      rescue JSON::ParserError
        raise ArgumentError, 'Installation record is invalid'
      end

      private

      def valid_record?(value)
        value.is_a?(Hash) && value['schema_version'] == 1 && value['directory'] == @root &&
          %w[repository branch revision].all? { |key| value[key].is_a?(String) && !value[key].empty? } &&
          valid_targets?(value['targets'])
      end

      def valid_targets?(targets)
        targets.is_a?(Array) && !targets.empty? && targets.all? do |target|
          target.is_a?(Hash) && target['directory'].is_a?(String) &&
            target['directory'].start_with?('/') && Package.valid_skills?(target['names'])
        end
      end
    end
  end
end
