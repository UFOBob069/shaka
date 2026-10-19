# frozen_string_literal: true

require 'rbconfig'
require_relative 'source'
require_relative 'directory_safety'
require_relative 'refusal'

module Shaka
  module Install
    # Direct links require an exact revision and protected files, not normalized copies.
    class DirectSource < Source
      include DirectorySafety

      def identity(hash)
        verify_modes
        verify_helper
        data = super
        raise ArgumentError, 'Installation files differ from the checkout revision' unless data['kind'] == 'revision'

        { 'schema_version' => 1, 'package_id' => nil, 'version' => version, 'skills' => @names, 'source' => data }
      end

      private

      def verify_helper
        output, status = Open3.capture2e({ 'SHAKA_RUBY' => RbConfig.ruby },
                                         File.join(@root, 'skills/shaka/scripts/shaka'), '--help', chdir: @root)
        raise ArgumentError, "Incoming Shaka helper failed verification: #{output.strip}" unless status.success?
      end

      def verify_modes
        entries = skill_paths.to_h { |path| [path, File.lstat(path)] }
        writable = entries.select { |_, entry| entry.mode.anybits?(0o022) }.keys
        foreign = entries.reject { |_, entry| trusted_owner?(entry) }.keys
        # Ownership comes first: chmod cannot fix a file another account owns.
        refuse_foreign(foreign) unless foreign.empty?
        refuse_writable(writable) unless writable.empty?
      end

      def skills_root = File.join(@root, 'skills')

      def skill_paths
        [skills_root] + @names.flat_map { |name| [File.join(skills_root, name)] + @tree.entries(@root, name) }
      end

      def refuse_writable(paths)
        raise ArgumentError, Refusal.message('Installation skills are group or world writable',
                                             Refusal.paths(paths), Refusal.command('chmod', '-R', 'go-w', skills_root))
      end

      def refuse_foreign(paths)
        raise ArgumentError, Refusal.message(
          'Installation skills belong to another account', Refusal.paths(paths),
          Refusal.decide('whether to trust these files', 'to see their owners',
                         Refusal.command('ls', '-ln', *paths.first(Refusal::PATH_LIMIT)))
        )
      end
    end
  end
end
