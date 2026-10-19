# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/decision_trial'
require_relative 'support/evaluation_budget_fixture'
require_relative 'support/evaluation_harbor_fixture'
require_relative 'support/evaluation_fingerprint_fixture'
require_relative 'support/evaluation_decision_fixture'

class EvaluationDecisionReplayTest < Minitest::Test
  include EvaluationBudgetFixture
  include EvaluationHarborFixture
  include EvaluationFingerprintFixture
  include EvaluationDecisionFixture

  def test_native_tier_one_replay_replaces_builder_guesses_and_settles_usage
    setup_harbor
    export_decision({ 'actions' => ['handoff'], 'reason' => 'private response' })
    account = budget
    assert_equal 'complete', decision_run(account)['status']
    saved = saved_harbor_record
    assert_equal 100, saved['score']
    assert_equal 'PASS', saved.dig('outcome', 'state')
    assert_equal '1.0', account.snapshot['monthly_dollars']
    refute_includes JSON.generate(saved), 'private response'
  end

  def test_native_fingerprint_and_inapplicable_fields_replace_builder_values
    setup_harbor
    capture_native_files('codex')
    decision_run
    saved = saved_harbor_record
    assert_equal '9.8.7', saved.dig('fingerprint', 'host_cli_version')
    fields = %w[fixture_ruby_version fixture_lockfile_hash local_reviewer_cli_versions judge_model_id
                judge_prompt_hash pinned_actions hosted_reviewer]
    assert_empty saved['judge']
    assert_equal ['N/A'], saved.fetch('fingerprint').values_at(*fields).uniq
    assert_empty Shaka::Evaluation::RunRecord.errors(saved)
  end

  def test_wrong_action_order_fails_without_a_judge_and_keeps_the_native_charge
    setup_harbor
    export_decision({ 'actions' => %w[merge handoff], 'reason' => 'wrong order' })
    assert_equal 'complete', decision_run(expected: %w[handoff merge])['status']
    saved = saved_harbor_record
    assert_equal 0, saved['score']
    assert_equal 'FAIL', saved.dig('outcome', 'state')
    refute saved.dig('gate', 0, 'passed')
    assert_empty saved['judge']
    assert_equal 1, saved.dig('usage', 'cache_neutral_dollars')
  end

  def test_missing_decision_is_a_scored_failure_not_an_unknown_charge
    setup_harbor
    assert_equal 'complete', decision_run['status']
    assert_equal 0, saved_harbor_record['score']
    assert_equal 'FAIL', saved_harbor_record.dig('outcome', 'state')
    assert_equal 0, budget.snapshot['pending']
  end

  def test_invalid_utf8_json_answer_is_failed_and_settled
    setup_harbor
    export_answer("{\"actions\":[\"handoff\"],\"reason\":\"\xff\"}".b)
    account = budget
    assert_equal 'complete', decision_run(account)['status']
    assert_equal 0, saved_harbor_record['score']
    assert_equal '1.0', account.snapshot['monthly_dollars']
    assert_equal 0, account.snapshot['pending']
  end

  def test_native_failure_overrides_a_correct_decision
    setup_harbor(mode: 'exception')
    export_decision({ 'actions' => ['handoff'], 'reason' => 'correct' })
    assert_equal 'harness_error', decision_run['status']
    assert_equal 'HARNESS_ERROR', saved_harbor_record.dig('outcome', 'state')
    assert_equal 'UNKNOWN', saved_harbor_record['score']
    assert_equal '1.0', budget.snapshot['monthly_dollars']
  end

  def test_invalid_expected_actions_stop_before_preflight_or_reservation
    setup_harbor
    assert_raises(ArgumentError) { decision_run(expected: ['invented']) }
    refute_path_exists File.join(@directory, 'observed.json')
    assert_equal 0, budget.snapshot['pending']
  end

  def test_other_tiers_cannot_use_decision_scoring
    setup_harbor
    [2, 3].each { |tier| assert_raises(ArgumentError) { decision_run(tier: tier) } }
    refute_path_exists File.join(@directory, 'observed.json')
    assert_equal 0, budget.snapshot['pending']
  end
end
