# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/evaluation_comparison_fixture'

class EvaluationComparisonTest < Minitest::Test
  include EvaluationComparisonFixture

  def test_skill_axis_allows_all_package_fields_together
    candidate.merge!('skill_package_digest' => "sha256:#{'d' * 64}", 'skill_commit' => 'e' * 40,
                     'skill_modified' => true, 'workflow_hash' => "sha256:#{'f' * 64}")
    result = comparison
    assert_equal 'eligible', result.fetch('status')
    assert_equal %w[skill_commit skill_modified skill_package_digest workflow_hash], result.fetch('differing_fields')
  end

  def test_other_axes_allow_only_the_named_change
    { 'model' => %w[configured_model other-model], 'provider' => %w[provider other-provider],
      'effort' => %w[effort low], 'tier' => %w[host_cli claude-code] }.each do |axis, (key, value)|
      candidate[key] = value
      assert_equal 'eligible', comparison(axis).fetch('status'), axis
      assert_equal 'refused', comparison.fetch('status'), axis
      candidate[key] = @baseline.first.fetch('fingerprint').fetch(key)
    end
  end

  def test_provider_change_with_a_different_served_model_suggests_tier
    candidate['provider'] = 'other-provider'
    candidate['routed_model'] = 'other-model'
    result = comparison('provider')
    assert_equal 'refused', result.fetch('status')
    assert_equal ['routed_model'], result.fetch('mismatches')
    assert_equal 'tier', result.fetch('suggested_axis')
  end

  def test_rate_card_and_environment_changes_are_always_refused
    %w[rate_card_hash runner_lockfile_hash container_image_digest].each do |field|
      candidate[field] = "sha256:#{'f' * 64}"
      assert_equal [field], comparison('tier').fetch('mismatches')
      candidate[field] = @baseline.first.fetch('fingerprint').fetch(field)
    end
  end

  def test_unknown_in_an_axis_field_is_provisional_even_when_equal
    [@baseline, @candidate].each { it.first['fingerprint']['routed_model'] = 'UNKNOWN' }
    result = comparison('model')
    assert_equal 'provisional', result.fetch('status')
    assert_equal ['routed_model'], result.fetch('provisional_fields')
  end

  def test_unknown_nested_evidence_is_provisional_without_exposing_its_key
    [@baseline, @candidate].each { it.first['fingerprint']['pinned_actions'] = { 'private-key' => 'UNKNOWN' } }
    result = comparison
    assert_equal ['pinned_actions'], result.fetch('provisional_fields')
    refute_includes JSON.generate(result), 'private-key'
  end

  def test_not_applicable_cannot_hide_a_required_identity
    [@baseline, @candidate].each { it.first['fingerprint']['machine_alias'] = 'N/A' }
    assert_equal 'provisional', comparison.fetch('status')
    assert_equal ['machine_alias'], comparison.fetch('provisional_fields')
  end

  def test_equal_numeric_resources_do_not_create_a_difference
    @baseline.first['fingerprint']['cpu_limit'] = 1
    candidate['cpu_limit'] = 1.0
    assert_equal 'eligible', comparison.fetch('status')
  end
end
