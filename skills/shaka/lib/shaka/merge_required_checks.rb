# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Refuses a merge unless every gating check (native, or seam-declared as a fallback) is passing.
  module MergeRequiredChecks
    EMPTY_REQUIRED_CHECKS = 'GitHub reported no required checks on this branch. Merge refuses that empty set. ' \
                            'If the branch is unprotected, enable branch protection or list merge.required_checks; ' \
                            'if required checks have not registered yet, wait and retry. ' \
                            'This is not unread evidence. In Ask mode, pass --empty-checks-confirmed-head for a head ' \
                            'the user told you to merge; Auto supplies no such approval.'

    private

    # confirmed_head names the head a user told the agent to merge knowing no check gates it.
    def verify_checks(checks, head: nil, confirmed_head: nil)
      raise Error, 'No observable required checks; native readiness is unknown' unless checks.is_a?(Array)
      return verify_empty_confirmation(head, confirmed_head) if checks.empty?

      checks.each do |check|
        next if passing_check?(check)

        raise Error, "Required check is not passing or is malformed: #{check.inspect}"
      end
    end

    def verify_empty_confirmation(head, confirmed_head)
      raise Error, EMPTY_REQUIRED_CHECKS unless confirmed_head
      return if confirmed_head == head

      raise Error, "Empty-checks confirmation names #{confirmed_head}, not the current head #{head}; " \
                   'ask the user to confirm this head'
    end

    # Reported only when the confirmation excused an empty set, so a merge result shows no check gated it.
    def excused_checks(gate, head)
      gate.fetch('checks').empty? ? { 'empty_required_checks_confirmed_head' => head } : {}
    end

    def passing_check?(check)
      return false unless check.is_a?(Hash) && check['name'].is_a?(String) && !check['name'].strip.empty?

      case check['state']
      when 'SUCCESS' then check['bucket'] == 'pass'
      when 'NEUTRAL', 'SKIPPED' then check['bucket'] == 'skipping'
      else false
      end
    end
  end
end
