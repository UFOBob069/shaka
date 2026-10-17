# frozen_string_literal: true

module Shaka
  # Chooses the checks that gate a PR. GitHub's native required checks win; the trusted
  # seam's merge.required_checks applies only when GitHub enforces none, as on a private
  # repository whose plan offers no branch protection.
  class RequiredChecks
    def initialize(github, seam_names: nil)
      @github = github
      @seam_names = seam_names
    end

    def call
      native = @github.required_checks
      return github(native) unless native.is_a?(Array)

      # The required-only report omits configured checks that never reported, and an empty
      # one can omit checks already present on the head.
      reported = native.map { |row| row['name'] if row.is_a?(Hash) }
      unreported = @github.configured_required_checks - reported
      checks = native + check_rows(unreported)
      return github(checks) unless checks.empty?
      return github([]) unless @seam_names&.any?

      { 'source' => 'seam', 'checks' => check_rows(@seam_names) }
    end

    private

    def github(checks) = { 'source' => 'github', 'checks' => checks }

    def missing(name) = { 'name' => name, 'state' => 'MISSING', 'bucket' => 'missing' }

    # A declared check that never reported on the head must block, so a renamed or removed
    # job fails closed instead of silently dropping out of the gate.
    def check_rows(names)
      return [] if names.empty?

      head = @github.checks
      names.flat_map do |name|
        rows = head.select { |row| row.is_a?(Hash) && row['name'] == name }
        rows.empty? ? [missing(name)] : rows
      end
    end
  end
end
