# frozen_string_literal: true

require_relative 'check'
require_relative '../configuration'
require_relative 'cli_inventory'

module Shaka
  class Doctor
    # Presence on PATH is evidence of an installed CLI, not of authentication or quota.
    class ReviewerClis
      include Check

      PROVIDERS = { 'codex' => 'openai', 'claude-code' => 'anthropic' }.freeze
      GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#add-a-second-reviewer'

      def initialize(root:, host:, environment:, system:, probe_reviewers: false)
        @root = root
        @probe_reviewers = probe_reviewers
        @provider = PROVIDERS[host]
        @inventory = CliInventory.new(root:, environment:, system:)
      end

      def call(seam)
        report(seam[:status] == 'healthy' ? Configuration.worktree(root: @root).review : nil)
      rescue Shaka::Error, SystemCallError
        report(nil)
      end

      private

      def report(review)
        entries = @inventory.call(review)
        warnings = readiness(entries, review)
        summary = entries.map { |entry| entry.fetch(:summary) } + warnings
        summary << 'No local reviewers configured; fresh host review remains available.' if
          review && entries.none? { |entry| entry[:configured] }
        summary << launch_summary
        check('Reviewer CLIs', warnings.empty? ? 'healthy' : 'degraded', summary.join("\n    "),
              guidance: guidance(entries, warnings))
      end

      def launch_summary
        return 'CLI presence does not establish sign-in, quota, or model access; see the availability probe.' if
          @probe_reviewers

        'Sign-in, quota, and CLI compatibility are unverified; no reviewer was launched.'
      end

      def readiness(entries, review)
        return ['Repository configuration unavailable; reviewer readiness is not assessed.'] unless review

        configured = entries.select { |entry| entry[:configured] }
        lines = warnings(configured, review.fetch('local_review_count', 1))
        lines.concat(CliInventory.setup_notices(configured).map { |notice| notice.fetch('summary') })
        lines << 'Some CLI lookups could not be checked.' if entries.any? { |entry| entry[:unchecked] }
        lines
      end

      def guidance(entries, warnings)
        lines = entries.filter_map { |entry| entry[:guidance] }
        lines << "Reviewer setup: #{GUIDE}" unless warnings.empty?
        lines << 'Configured reviewer setup is recommended; other providers are optional.' unless lines.empty?
        lines.empty? ? nil : lines.join("\n    ")
      end

      def warnings(entries, count)
        return [] if entries.empty?

        providers = entries.select { |entry| entry[:installed] }.map { |entry| entry[:provider] }.uniq
        lines = []
        lines << "#{providers.size} provider#{'s' unless providers.one?} available; #{count} reviewers requested." if
          providers.size < count
        if providers == [@provider]
          lines << "Only the current host's provider (#{@provider}) is available; no different-provider CLI was found."
        end
        lines
      end
    end
  end
end
