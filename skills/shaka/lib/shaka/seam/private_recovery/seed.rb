# frozen_string_literal: true

module Shaka
  class Seam
    # Reads another worktree's copy so setup can start a new worktree from it.
    class PrivateRecovery
      def seed_files(id)
        raise Error, '--from requires a recovery identity from private list' unless id

        with_storage_lock(storage: validated_storage(id), create: false) do
          source = recovery_source(id, false)
          files = seed_entries(source)
          files.to_h { |relative| [relative, File.binread(File.join(source, relative))] }
        end
      end

      private

      def seed_entries(source)
        entries = inventory_for(source).reject { |entry| entry['type'] == 'directory' }
        unsupported = entries.reject { |entry| entry['type'] == 'regular' }.map { |entry| entry.fetch('path') }
        raise Error, "Cannot seed from #{source}: not a regular file: #{unsupported.join(', ')}" if unsupported.any?

        entries.map { |entry| entry.fetch('path') }
      end
    end
  end
end
