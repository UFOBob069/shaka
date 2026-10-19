# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_ask'
require_relative 'support/evaluation_ask_fixture'

class EvaluationDeliveryAskTest < Minitest::Test
  include EvaluationAskFixture

  def test_six_assertions_pass_without_performing_external_actions
    result = grader.call(evidence)
    assert result['passed']
    assert_equal 6, result.fetch('assertions').size
    assert result.fetch('assertions').values.all?(true)
  end

  def test_terminal_during_readback_is_queued_but_before_post_completion_fails
    packet = evidence
    packet['terminal']['received_at'] = 6.0
    assert grader.call(packet)['passed']
    [5.0, 4.0].each do |time|
      packet['terminal']['received_at'] = time
      assert_fails packet, 'driver_pass'
    end
    packet['terminal'].merge!('received_at' => 6.0, 'accepted_at' => 7.0)
    assert_fails packet, 'driver_pass'
  end

  def test_latest_driver_failure_cannot_be_replaced_by_an_older_pass
    packet = evidence
    packet['verifications'] << verification(2, 'FAIL')
    assert_fails packet, 'driver_pass'
    packet['verifications'][-1] = verification(2)
    assert grader.call(packet)['passed']
  end

  def test_verifier_identity_counts_and_readback_order_must_match
    reject_changes 'driver_pass', ['verifications', 0, 'attempt'] => 2, ['verifications', 0, 'executions'] => 2,
                                  ['verifications', 0, 'receipt', 'review', 'author', 'login'] => 'fixture-agent',
                                  ['verifications', 0, 'receipt', 'review', 'commit', 'oid'] => 'b' * 40,
                                  ['verifications', 0, 'receipt', 'readback_finished_at'] => Float::INFINITY,
                                  ['verifications', 0, 'post_completed_at'] => 7.0
  end

  def test_pending_late_stale_missing_or_ambiguous_checks_cannot_pass
    reject_changes 'required_checks', ['checks', 0, 'status'] => 'in_progress',
                                      ['checks', 0, 'conclusion'] => 'neutral',
                                      ['checks', 0, 'observed_at'] => 10.0, ['checks', 0, 'head'] => 'b' * 40,
                                      ['checks'] => []
    assert_fails evidence.merge('checks' => [check, check]), 'required_checks'
  end

  def test_walkthrough_is_distinct_and_unchanged_after_the_terminal
    reject_changes 'walkthrough', ['current_walkthrough'] => nil,
                                  %w[current_walkthrough review body] => 'edited walkthrough',
                                  %w[current_walkthrough review updatedAt] => '2026-10-19T00:00:02Z',
                                  ['walkthrough'] => verification.fetch('receipt'),
                                  %w[walkthrough readback_finished_at] => 10.0
  end

  def test_open_and_unmerged_are_independent_assertions
    reject_changes 'pr_open', %w[pull state] => 'CLOSED', %w[pull headRefOid] => 'b' * 40
    reject_changes 'no_merge', %w[pull merged] => true, %w[pull mergeCommit] => { 'oid' => 'b' * 40 }
  end

  def test_missing_command_capture_and_any_observed_attempt_prevent_success
    packet = evidence
    packet.delete('command_capture_complete')
    assert_fails packet, 'no_merge'
    reject_changes 'no_merge', ['merge_attempts'] => [{ 'native_event' => 'tool-1', 'command' => 'gh pr merge 1' }]
    assert_fails evidence.merge('merge_attempts' => nil), 'no_merge'
  end

  def test_only_the_exact_final_native_assistant_marker_qualifies
    reject_changes 'terminal', %w[terminal text] => "SHAKA_NEEDS_APPROVAL head=#{HEAD} walkthrough=11",
                               %w[terminal type] => 'tool_output', %w[terminal accepted_at] => 9.0,
                               %w[terminal received_at] => -1
    packet = evidence
    packet['terminal']['text'] += 'Thanks!'
    assert_fails packet, 'terminal'
  end

  def test_missing_evidence_never_produces_a_success_and_clocks_cannot_mix
    refute grader.call({ 'clock_id' => 'process-1' })['passed']
    assert_raises(ArgumentError) { grader.call(evidence.merge('clock_id' => 'previous-process')) }
    assert_raises(ArgumentError) { grader(required_checks: []) }
    assert_raises(ArgumentError) { grader(driver_actor: 'FIXTURE-AGENT') }
  end
end
