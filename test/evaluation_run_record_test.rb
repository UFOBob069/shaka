# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/run_record'

class EvaluationRunRecordTest < Minitest::Test
  FIXTURE = File.expand_path('fixtures/evaluation-run-record.json', __dir__)

  def setup
    @record = JSON.parse(File.read(FIXTURE))
  end

  def errors = Shaka::Evaluation::RunRecord.errors(@record)

  def test_synthetic_record_is_valid_without_becoming_a_release_verdict
    original = Marshal.dump(@record)
    assert_empty errors
    assert_equal original, Marshal.dump(@record)
  end

  def test_missing_fields_are_not_defaulted
    @record['fingerprint'].delete('routed_model')
    assert_includes errors, '$.fingerprint.routed_model: missing'
    @record.delete('usage')
    assert_includes errors, '$.usage: missing'
  end

  def test_wrong_root_shapes_return_errors
    [nil, [], 'private-value', true].each do |value|
      refute_empty Shaka::Evaluation::RunRecord.errors(value)
    end
  end

  def test_unknown_and_not_applicable_remain_distinct_values
    @record['fingerprint']['container_image_digest'] = 'UNKNOWN'
    assert_empty errors
    assert_equal 'UNKNOWN', @record.dig('fingerprint', 'container_image_digest')
    @record['fingerprint']['container_image_digest'] = nil
    refute_empty errors
  end

  def test_digests_reject_tags_and_trailing_newlines
    ['ruby:latest', "sha256:#{'a' * 64}\n", 'sha256:short'].each do |value|
      @record['fingerprint']['container_image_digest'] = value
      refute_empty errors
    end
  end

  def test_non_boolean_modified_flag_and_unknown_schema_version_fail
    @record['fingerprint']['skill_modified'] = 'false'
    refute_empty errors
    @record['fingerprint']['skill_modified'] = false
    @record['schema_version'] = 2
    refute_empty errors
  end

  def test_metrics_reject_negative_fractional_and_nonfinite_counts
    [-1, 1.5, Float::NAN, Float::INFINITY].each do |value|
      @record['usage']['models'][0]['input_tokens'] = value
      refute_empty errors
    end
    @record['usage']['models'][0]['input_tokens'] = 1.0
    assert_empty errors # JSON Schema integer means a number with no fractional part.
  end

  def test_unknown_metrics_are_not_zero_or_not_applicable
    @record['usage']['cache_neutral_dollars'] = 'UNKNOWN'
    assert_empty errors
    @record['usage']['cache_neutral_dollars'] = 'N/A'
    refute_empty errors
    @record['usage']['cache_neutral_dollars'] = -1
    refute_empty errors
  end

  def test_harness_error_requires_detail_and_other_states_exclude_it
    @record['outcome'] = { 'state' => 'HARNESS_ERROR', 'harness_error' => nil }
    refute_empty errors
    @record['outcome']['harness_error'] = 'Synthetic setup failure'
    assert_empty errors
    @record['outcome']['state'] = 'PASS'
    refute_empty errors
  end

  def test_task_bank_identity_cannot_disagree_with_the_fingerprint
    @record['task']['bank_version'] = 'd' * 40
    assert_includes errors, '$.task.bank_version: differs from fingerprint.task_bank_version'
  end

  def test_nested_judge_and_artifact_fields_are_checked
    @record['judge'] = [{ 'model_id' => 'synthetic-judge' }]
    refute_empty errors
    @record['judge'] = []
    @record['artifacts'][0]['digest'] = 'a' * 64
    refute_empty errors
  end

  def test_judge_call_records_the_unknown_escape_and_order
    @record['task']['tier'] = 2
    @record['judge'] = [{ 'model_id' => 'synthetic-judge', 'prompt_hash' => "sha256:#{'a' * 64}",
                          'kind' => 'pairwise_ba', 'dimension' => 'N/A', 'verdict' => 'Unknown',
                          'confidence' => 'Unknown', 'critique' => 'Synthetic order check',
                          'facts' => { 'check_passed' => true } }]
    @record['score'] = 0
    assert_empty errors
    @record['judge'][0]['kind'] = 'pairwise'
    refute_empty errors
  end

  def test_diagnostics_omit_private_values_and_unknown_property_names
    @record['fingerprint']['private-secret-key'] = 'private-secret-value'
    @record['fingerprint']['host_cli'] = 'private-secret-value'
    refute_empty errors
    refute_includes errors.join, 'private-secret'
  end

  def test_checker_refuses_unsupported_keywords_in_unused_schema_branches
    schema = { '$defs' => { 'unused' => { 'minItems' => 1 } } }
    assert_raises(ArgumentError) { Shaka::Evaluation::Schema.new(schema) }
    assert_raises(ArgumentError) { Shaka::Evaluation::Schema.new({ '$ref' => 'https://example.invalid/schema' }) }
  end
end
