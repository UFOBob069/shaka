# frozen_string_literal: true

require 'shellwords'
require_relative 'directory_safety'
require_relative 'tree'
require_relative 'status_states'

module Shaka
  module Install
    # File and directory modes the installer refuses, read without changing anything.
    module StatusModes
      include DirectorySafety

      # DirectorySafety's reasons for a writable directory; the rest of its message is the path.
      WRITABLE = [' is group or world writable without a sticky bit protecting your directory',
                  ' is group or world writable'].freeze

      private

      def unsafe
        [@root, File.join(@root, '.git')].each { |path| verify_safe_directory(path, 'Installation directory') }
        nil
      rescue ArgumentError => e
        offending = e.message.sub(/\A[^:]*: /, '')
        path = WRITABLE.map { |reason| offending.delete_suffix(reason) }.find { |trimmed| trimmed != offending }
        return finding('B10', e.message, command: "chmod go-w #{Shellwords.escape(path)}") if path

        finding('B10', e.message, decision: 'Move the installation to a directory you own, then rerun bin/install.')
      end

      # Installation verification refuses these same modes, so status names them before it does.
      def unsafe_files
        skills = File.join(@root, 'skills')
        # A symlink's own mode is meaningless and chmod cannot change it; the installer refuses symlinks itself.
        path = skill_paths(skills).find { |entry| !File.symlink?(entry) && unprotected?(File.lstat(entry)) }
        return unless path

        finding('B10', "#{path} is group or world writable or owned by another account",
                command: "chmod -R go-w #{Shellwords.escape(skills)}")
      rescue SystemCallError
        nil
      end

      # The installer's own file list: it leaves out ignored files and refuses symlinks on its own.
      def skill_paths(skills)
        names = @record['targets'].flat_map { |target| target['names'] }.uniq
        tree = Tree.new(names, source_root: @root)
        [skills] + names.flat_map { |name| [File.join(skills, name)] + tree.entries(@root, name) }
      rescue ArgumentError
        [skills]
      end

      def unprotected?(entry) = entry.mode.anybits?(0o022) || !trusted_owner?(entry)
    end
  end
end
