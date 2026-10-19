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
      OWNERSHIP = 'Make your account the owner of the skill files (chown needs that account or root), ' \
                  'then rerun status.'

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

      # Installation verification refuses these same files; each kind gets a step that can fix it.
      def unsafe_files
        skills = File.join(@root, 'skills')
        paths = skill_paths(skills)
        return refused if @refusal

        symlink(paths) || foreign(paths) || special(paths, skills) || writable(paths, skills)
      rescue SystemCallError
        nil
      end

      # The installer's own refusal of the skill files, which Git may not show, such as a helper that
      # lost its execute bit under core.filemode=false.
      def refused
        helper = @refusal[/\ASkill helper is not executable: (.+)\z/, 1]
        return finding('B10', @refusal, command: "chmod a+x #{Shellwords.escape(helper)}") if helper

        finding('B3', "installation refuses the skill files: #{@refusal}",
                decision: 'Fix or restore the file it names, then rerun status.')
      end

      def symlink(paths)
        link = paths.find { |path| File.symlink?(path) }
        return unless link

        finding('B10', "#{link} is a symlink, which installation refuses", decision: "Move #{link} out of the skill.")
      end

      def foreign(paths)
        path = paths.find { |entry| !owned?(entry) }
        finding('B10', "#{path} is owned by another account", decision: OWNERSHIP) if path
      end

      # The installer refuses setuid, setgid, or sticky bits on files, and setuid or sticky on directories.
      def special(paths, skills)
        path = paths.find { |entry| File.lstat(entry).mode.anybits?(File.directory?(entry) ? 0o5000 : 0o7000) }
        return unless path

        finding('B10', "#{path} has a setuid, setgid, or sticky bit",
                command: "chmod -R a-st #{Shellwords.escape(skills)}")
      end

      def writable(paths, skills)
        path = paths.find { |entry| File.lstat(entry).mode.anybits?(0o022) }
        return unless path

        finding('B10', "#{path} is group or world writable", command: "chmod -R go-w #{Shellwords.escape(skills)}")
      end

      # Git ignores mode changes such as 0644 to 0600, but the recorded identity hashes every mode, so
      # verification refuses them; compare that hash when the checkout sits at its recorded revision.
      def changed_contents
        return unless value('rev-parse', 'HEAD') == @record['revision']

        recorded = @record.dig('identity', 'source', 'content_sha256')
        names = @record['targets'].flat_map { |target| target['names'] }.uniq
        return if recorded.nil? || Tree.new(names, source_root: @root).hash(@root) == recorded

        finding('B3', 'skill files or their modes changed since installation, though Git shows no change',
                decision: 'Restore the files you changed, or rerun bin/install to accept the current files.')
      rescue ArgumentError, SystemCallError
        nil
      end

      def owned?(path) = trusted_owner?(File.lstat(path))

      # The installer's own file list, which leaves out ignored files.
      def skill_paths(skills)
        names = @record['targets'].flat_map { |target| target['names'] }.uniq
        tree = Tree.new(names, source_root: @root)
        [skills] + names.flat_map { |name| [File.join(skills, name)] + tree.entries(@root, name) }
      rescue ArgumentError => e
        @refusal = e.message
        [skills]
      end
    end
  end
end
