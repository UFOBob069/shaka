# frozen_string_literal: true

require_relative 'refusal'

module Shaka
  module Install
    # Names what occupies a skill link's place, who owns it, and the one step that clears it.
    module LinkRefusal
      private

      def existing_refusal(state, name, repair)
        return entry_refusal(state, destination(name)) unless File.symlink?(destination(name))

        target = File.expand_path(old_target(name), @skills_dir)
        owner = Refusal.owner(target)
        found = "it points to #{target}, owned by #{owner || unregistered_owner(name)}"
        repair = Refusal.decide('which installation to keep', 'to use this one', repair) if owner
        Refusal.message(state, found, repair)
      end

      def entry_refusal(state, path)
        kind = File.directory?(path) ? 'directory' : 'file'
        Refusal.message(state, "it is a #{kind}, not a skill link", move_aside(path),
                        note: 'Moving it aside keeps its contents')
      end

      def unregistered_owner(name)
        managed_target?(name, old_target(name)) ? "a managed copy in #{@managed}" : 'no registered installation'
      end

      # Never suggests a destination that already exists, so moving aside cannot replace an earlier backup.
      def move_aside(path)
        backup = base = "#{path}.before-shaka"
        index = 1
        backup = "#{base}-#{index += 1}" while File.exist?(backup) || File.symlink?(backup)
        Refusal.command('mv', path, backup)
      end
    end
  end
end
