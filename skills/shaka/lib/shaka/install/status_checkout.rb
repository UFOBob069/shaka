# frozen_string_literal: true

require 'shellwords'
require_relative 'official'
require_relative 'status_git'
require_relative 'status_revision'
require_relative 'directory_safety'
require_relative 'status_states'

module Shaka
  module Install
    # Reads one registered checkout's Git state without changing it or reaching the network.
    class StatusCheckout
      include StatusGit
      include StatusRevision
      include DirectorySafety

      attr_reader :root, :record

      def initialize(root, record)
        @root = root
        @record = record
      end

      def helper = command(File.join(@root, 'skills/shaka/scripts/shaka'))
      def installer = command(File.join(@root, 'bin/install'))

      # Git reads a writable checkout's config, which can name commands to run, so an unsafe
      # checkout gets no Git read at all, as the installer refuses it before any Git command.
      def findings
        safety = unsafe
        return [safety] if safety

        [origin, branch, dirty, revision, pending, ruby, development].compact
      end

      private

      def unsafe
        [@root, File.join(@root, '.git')].each { |path| verify_safe_directory(path, 'Installation directory') }
        nil
      rescue ArgumentError => e
        path = e.message.split(': ', 2).last.sub(/ (is|cannot) .*\z/m, '')
        return finding('B10', e.message, command: "chmod go-w #{command(path)}") if e.message.include?('writable')

        finding('B10', e.message, decision: 'Move the installation to a directory you own, then rerun bin/install.')
      end

      def origin
        actual = value('config', '--get', 'remote.origin.url')
        return if actual == @record['repository']

        finding('B5', "origin is #{actual || 'missing'}; the record expects #{@record['repository']}",
                command: "#{git_command} remote set-url origin #{command(@record['repository'])}")
      end

      def branch
        current = value('branch', '--show-current').to_s
        return upstream if current == @record['branch']

        finding('B4', "checkout is on #{current.empty? ? 'a detached HEAD' : current}; " \
                      "the record expects #{@record['branch']}",
                command: "#{git_command} switch #{command(@record['branch'])}")
      end

      # Verification and update both require this upstream. Reading the config, not the ref, leaves
      # a missing tracking ref to the revision check, which asks for a fetch.
      def upstream
        name = @record['branch']
        remote, merge = %w[remote merge].map { |key| value('config', '--get', "branch.#{name}.#{key}") }
        return if remote == 'origin' && merge == "refs/heads/#{name}"

        tracked = remote ? "#{remote}/#{merge.to_s.delete_prefix('refs/heads/')}" : 'no upstream'
        finding('B4', "#{name} tracks #{tracked}, not origin/#{name}",
                command: "#{git_command} branch --set-upstream-to origin/#{command(name)}")
      end

      def dirty
        # Without --no-optional-locks, status refreshes the index, and a read-only report must not write.
        changes = value('--no-optional-locks', 'status', '--porcelain', '--untracked-files=all').to_s
        files = changes.lines.map { |line| line[3..].strip }
        return if files.empty?

        finding('B3', "uncommitted files: #{listed(files)}",
                decision: 'Keep or discard these edits yourself; move kept work to a development checkout.')
      end

      def pending
        target = @record['pending_revision']
        return unless target

        finding('B7', "an update to #{target[0, 7]} did not finish", command: "#{installer} --update")
      end

      def ruby
        path = File.join(@root, '.git', Official::RUBY_RECORD)
        recorded = File.file?(path) ? File.read(path).strip : nil
        return if recorded && File.executable?(recorded)

        finding('B8', "recorded Ruby #{recorded || 'is missing'}#{' is unavailable' if recorded}; " \
                      'run the next command with Ruby 3.4 or later first on PATH',
                command: installer)
      rescue SystemCallError => e
        finding('B8', "recorded Ruby cannot be read: #{e.message}", command: installer)
      end

      def development
        uses = [linked_worktrees, extra_branches].compact
        return if uses.empty?

        finding('C3', "source checkout is also used for development: #{uses.join('; ')}",
                decision: "Move development to a separate clone; the source checkout keeps only #{@record['branch']}.")
      end

      def linked_worktrees
        count = value('worktree', 'list', '--porcelain').to_s.lines.grep(/\Aworktree /).size - 1
        "#{count} linked worktree(s)" if count.positive?
      end

      def extra_branches
        branches = value('for-each-ref', '--format=%(refname:short)', 'refs/heads').to_s.lines.map(&:strip)
        extra = branches - [@record['branch']]
        "local branches #{listed(extra)}" if extra.any?
      end

      def git_command = "git -C #{command(@root)}"
      def command(text) = Shellwords.escape(text)

      def finding(id, detail, **) = StatusStates.finding(id, @root, detail, **)
    end
  end
end
