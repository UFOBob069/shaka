# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/harbor_trial'
require_relative 'support/evaluation_budget_fixture'
require_relative 'support/evaluation_harbor_fixture'
require_relative 'support/evaluation_fingerprint_fixture'

class EvaluationHarborFingerprintTest < Minitest::Test
  include EvaluationBudgetFixture
  include EvaluationHarborFixture
  include EvaluationFingerprintFixture

  def test_native_observation_replaces_guessed_builder_fields
    setup_harbor
    with_machine_alias('synthetic-alias') { harbor_run }
    fingerprint = saved_harbor_record.fetch('fingerprint')
    expected = { 'host_cli_version' => 'UNKNOWN', 'machine_alias' => 'synthetic-alias', 'host_cli' => 'codex',
                 'runner_ruby_version' => RUBY_VERSION, 'cpu_limit' => 2, 'memory_limit_bytes' => 2_147_483_648,
                 'container_image_digest' => "sha256:#{'a' * 64}", 'skill_package_digest' => 'UNKNOWN' }
    assert_equal expected, fingerprint.slice(*expected.keys)
  end

  def test_complete_native_fields_and_explicit_operator_evidence_reach_the_saved_record
    setup_harbor
    capture_native_files('codex')
    observed_usage
    run_with_evidence(native_evidence)
    fingerprint = saved_harbor_record.fetch('fingerprint')
    expected = { 'host_cli_version' => '9.8.7', 'configured_model' => 'configured', 'routed_model' => 'UNKNOWN',
                 'effort' => 'high', 'machine_alias' => 'private-machine', 'fixture_ruby_version' => '3.4.6',
                 'judge_model_id' => 'N/A', 'judge_prompt_hash' => 'UNKNOWN' }
    assert_equal expected, fingerprint.slice(*expected.keys)
  end

  def test_locked_package_reaches_a_structurally_valid_record
    setup_harbor
    capture_native_files('codex')
    harbor_run
    fingerprint = saved_harbor_record.fetch('fingerprint')
    assert_match(/\Asha256:[a-f0-9]{64}\z/, fingerprint['skill_package_digest'])
    assert_equal Shaka::Evaluation::SkillSnapshot.read(@skill)['workflow_hash'], fingerprint['workflow_hash']
    assert_empty Shaka::Evaluation::RunRecord.errors(saved_harbor_record)
  end

  def test_claude_version_comes_from_native_events_not_requested_pin
    setup_harbor(host: 'claude-code')
    capture_native_files('claude-code')
    harbor_run
    assert_equal '9.8.7', saved_harbor_record.dig('fingerprint', 'host_cli_version')
    assert_equal 'requested-model', saved_harbor_record.dig('fingerprint', 'configured_model')
    assert_equal 'medium', saved_harbor_record.dig('fingerprint', 'effort')
    assert_equal 'UNKNOWN', saved_harbor_record.dig('fingerprint', 'routed_model')
  end

  def test_a_conflicting_native_cli_version_stays_unknown
    setup_harbor
    capture_native_files('codex', second_version: '9.8.6')
    harbor_run
    assert_equal 'UNKNOWN', saved_harbor_record.dig('fingerprint', 'host_cli_version')
  end

  def test_lock_mismatch_does_not_claim_the_operator_package
    setup_harbor
    capture_native_files('codex', lock_digest: "sha256:#{'f' * 64}")
    harbor_run
    assert_equal 'UNKNOWN', saved_harbor_record.dig('fingerprint', 'skill_package_digest')
    assert_equal 'UNKNOWN', saved_harbor_record.dig('fingerprint', 'workflow_hash')
  end

  def test_tree_changed_during_launch_stays_unknown
    setup_harbor
    capture_native_files('codex', mutate: true)
    harbor_run
    assert_equal 'UNKNOWN', saved_harbor_record.dig('fingerprint', 'skill_package_digest')
  end

  def test_operator_cannot_supply_a_requested_pin_as_native_evidence
    setup_harbor
    assert_raises(ArgumentError) do
      run_with_evidence({ tasks.first.fetch('id') => { 'host_cli_version' => 'requested-pin' } })
    end
    refute_path_exists File.join(@directory, 'observed.json')
    assert_equal 0, budget.snapshot['pending']
  end
end
