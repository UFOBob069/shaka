# frozen_string_literal: true

require 'shellwords'

module Shaka
  module Install
    # Finds linked worktrees and extra local branches, which mean the source checkout is used for development.
    module CheckoutDevelopment
      SOURCE_EXAMPLE = '~/.local/share/shaka/source'

      # Installation refuses development use; maintenance only warns, so an existing install keeps working.
      def check_development_use(action)
        uses = development_uses
        return if uses.empty?

        detail = "Installation checkout #{@root} is also used for development (#{uses.join('; ')})."
        raise ArgumentError, "#{detail} #{development_next_step}" if action == :install

        warn "Warning: #{detail} Pulls, branches, and commits there stop updates. #{development_next_step}"
      end

      # A worktree disappears when its branch merges, taking every host link with it, so no action proceeds.
      def refuse_linked_worktree
        return unless File.file?(File.join(@root, '.git'))

        git_directory, common = git('rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir').split("\n")
        return if git_directory == common

        raise ArgumentError, "Installation checkout #{@root} is a linked worktree of #{File.dirname(common)}. " \
                             "Install from a separate clone: git clone #{@repository || Checkout::REPOSITORY} " \
                             "#{SOURCE_EXAMPLE} && #{SOURCE_EXAMPLE}/bin/install --directory #{SOURCE_EXAMPLE}"
      end

      private

      def development_uses
        worktrees = linked_worktrees
        branches = git('for-each-ref', '--format=%(refname:lstrip=2)', 'refs/heads/').lines.map(&:strip) - [@branch]
        uses = []
        uses << "linked worktrees: #{worktrees.join(', ')}" unless worktrees.empty?
        uses << "local branches: #{branches.join(', ')}" unless branches.empty?
        uses
      end

      # The first porcelain entry is the main worktree; prunable entries no longer exist on disk.
      def linked_worktrees
        entries = git('worktree', 'list', '--porcelain').split(/\n\n+/).drop(1)
        entries.grep_v(/^prunable/)
               .filter_map { |entry| entry[/^worktree (.+)$/, 1] }
               .reject { |path| path == @root }
      end

      def development_next_step
        command = "#{Shellwords.escape(File.join(@root, 'bin/install'))} --directory #{SOURCE_EXAMPLE}"
        command += ' --take-over' if @record
        "Keep this clone for development and give Shaka its own checkout: #{command}"
      end
    end
  end
end
