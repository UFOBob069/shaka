# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/evaluation_comparison_fixture'

class EvaluationComparisonSetsTest < Minitest::Test
  include EvaluationComparisonFixture

  def test_empty_invalid_or_reused_records_are_refused
    @candidate.clear
    assert_equal 'invalid_records', comparison.fetch('reason')
    @candidate << copy(@baseline.first).merge('score' => 101)
    assert_equal 'invalid_records', comparison.fetch('reason')
    @candidate = copy(@baseline)
    assert_equal 'repeated_trial', comparison.fetch('reason')
  end

  def test_task_sets_must_match
    @candidate.first['task']['id'] = 'another-task'
    assert_equal 'unmatched_tasks', comparison.fetch('reason')
  end

  def test_task_metadata_must_match
    @candidate.first['task']['kind'] = 'capability'
    assert_equal 'unmatched_tasks', comparison.fetch('reason')
  end

  def test_trial_counts_must_match
    add_trial(@candidate, 'extra-trial')
    assert_equal 'unmatched_tasks', comparison.fetch('reason')
  end

  def test_each_arm_must_be_stable_even_for_the_comparison_axis
    add_trial(@baseline, 'second-baseline')
    add_trial(@candidate, 'second-candidate')
    @candidate.last['fingerprint']['skill_modified'] = true
    assert_equal 'refused', comparison.fetch('status')
    assert_equal ['skill_modified'], comparison.fetch('mismatches')
  end

  def test_a_batch_cannot_mix_models_between_tasks
    [@baseline, @candidate].each_with_index do |arm, index|
      extra = copy(arm.first).merge('trial_id' => "other-#{index}")
      extra['task']['id'] = 'second-task'
      extra['fingerprint']['configured_model'] = 'second-model'
      arm << extra
    end
    assert_equal 'refused', comparison.fetch('status')
    assert_equal ['configured_model'], comparison.fetch('mismatches')
  end

  def test_baseline_calibration_with_no_axis_change_is_eligible
    assert_equal 'eligible', comparison.fetch('status')
    assert_empty comparison.fetch('differing_fields')
  end

  def test_invalid_axis_is_never_echoed
    result = comparison('private-value')
    assert_equal 'invalid_axis', result.fetch('reason')
    refute_includes JSON.generate(result), 'private-value'
  end
end
