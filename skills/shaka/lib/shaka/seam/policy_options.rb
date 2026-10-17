# frozen_string_literal: true

require_relative '../error'
require_relative '../reviewer_selection'

module Shaka
  class Seam
    # Review and merge flags for `shaka seam init`; private setup shares the reviewer flag.
    module PolicyOptions
      private

      def add_policy_options(flags)
        add_review_policy_options(flags)
        flags.on('--merge-preference MODE', %w[ask auto], 'ask or auto (default: ask)') do |value|
          @options[:merge_preference] = value
        end
        flags.on('--required-check NAME', 'Check gating merge when GitHub requires none; repeatable') do |value|
          (@options[:required_checks] ||= []) << value
        end
      end

      def add_review_policy_options(flags)
        flags.on('--review-policy MODE', %w[always meaningful_changes none],
                 'always, meaningful_changes, or none') { |value| @options[:review_policy] = value }
        add_ci_review_job_flag(flags)
        add_local_review_agent_flag(flags)
        reject_retired_review_flags(flags)
      end

      def add_local_review_agent_flag(flags)
        flags.on('--local-review-agent PROVIDER/FAMILY', 'Local reviewer in preference order; repeatable') do |value|
          (@options[:local_review_agents] ||= []) << ReviewerSelection.parse(value)
        end
      end

      def add_ci_review_job_flag(flags)
        flags.on('--ci-review-job NAME', 'CI review job name; repeat for another job') do |value|
          (@options[:ci_review_jobs] ||= []) << value
        end
      end

      def reject_retired_review_flags(flags)
        flags.on('--ci-review-agent NAME', 'Renamed to --ci-review-job') do
          raise Error, '--ci-review-agent moved to --ci-review-job'
        end
        flags.on('--github-action-check NAME', 'Renamed to --ci-review-job') do
          raise Error, '--github-action-check moved to --ci-review-job'
        end
        flags.on('--review-check NAME', 'Renamed to --ci-review-job') do
          raise Error, '--review-check moved to --ci-review-job'
        end
      end
    end
  end
end
