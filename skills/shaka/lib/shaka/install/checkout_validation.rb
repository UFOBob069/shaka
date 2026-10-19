# frozen_string_literal: true

require_relative 'refusal'

module Shaka
  module Install
    # Refuses a checkout that left its registered origin, branch, or clean tree, and names the way back.
    module CheckoutValidation
      private

      def validate
        raise ArgumentError, 'Unexpected installation checkout root' unless git('rev-parse', '--show-toplevel') == @root

        validate_origin
        validate_branch
        validate_tracking
        validate_revision
      end

      def validate_origin
        origin = git('config', '--get', 'remote.origin.url')
        return if origin == @repository

        expected = Refusal.url(@repository)
        raise ArgumentError, Refusal.message(
          'Installation origin differs from the expected repository',
          "#{@root} has origin #{Refusal.url(origin)}; expected #{expected}",
          Refusal.decide('which repository this installation follows', "to keep #{expected}",
                         Refusal.command('git', '-C', @root, 'remote', 'set-url', 'origin', expected)),
          note: "To install #{Refusal.url(origin)} instead, rerun bin/install with --repository and that URL"
        )
      end

      def validate_branch
        current = git('branch', '--show-current')
        return if current == @branch

        current = current.empty? ? "a detached HEAD at #{revision[0, 7]}" : "branch #{current}"
        raise ArgumentError, Refusal.message('Installation checkout is not on the registered branch',
                                             "#{@root} is on #{current}; expected #{@branch}",
                                             Refusal.command('git', '-C', @root, 'switch', @branch))
      end

      def validate_tracking
        return if tracking == "origin/#{@branch}"

        raise ArgumentError, Refusal.message("Installation branch #{@branch} does not follow origin/#{@branch}",
                                             "#{@root} follows #{tracking || 'no remote branch'}",
                                             Refusal.command('git', '-C', @root, 'branch', '-u',
                                                             "origin/#{@branch}", @branch))
      end

      # Git names a missing tracking branch in its own words, so report that case as absent.
      def tracking
        git('rev-parse', '--abbrev-ref', '@{upstream}')
      rescue ArgumentError
        nil
      end

      def validate_revision
        changes = git('status', '--porcelain', '--untracked-files=all')
        unless changes.empty?
          paths = changes.lines.map { |line| line.lstrip.sub(/\A\S+\s+/, '').chomp }
          raise ArgumentError, Refusal.message('Installation checkout has uncommitted changes',
                                               "#{Refusal.paths(paths)} in #{@root}",
                                               Refusal.command('git', '-C', @root, 'stash', 'push',
                                                               '--include-untracked'),
                                               note: 'Set them aside and develop in a separate checkout')
        end

        refuse_drift
      end

      # A fast-forward would fail on rewritten history; say so before Git reports it in its own words.
      def refuse_rewrite(candidate)
        return if ancestor?(revision, candidate)

        raise ArgumentError, Refusal.message(
          "#{Refusal.branch(@repository, @branch).sub(/\At/, 'T')} was rewritten and no longer has this installation",
          "#{@root} stays at #{revision[0, 7]}, unchanged; origin/#{@branch} is at #{candidate[0, 7]}",
          Refusal.decide('whether to trust the new history', 'to compare them',
                         Refusal.command('git', '-C', @root, 'log', '--oneline', '--left-right',
                                         "HEAD...origin/#{@branch}"))
        )
      end
    end
  end
end
