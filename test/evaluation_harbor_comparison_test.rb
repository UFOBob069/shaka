# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/evaluation_comparison_fixture'
require_relative 'support/evaluation_harbor_environment_fixture'
require_relative '../eval/lib/shaka/evaluation/harbor_environment'

class EvaluationHarborComparisonTest < Minitest::Test
  include EvaluationComparisonFixture
  include EvaluationHarborEnvironmentFixture

  def test_legacy_harbor_records_without_container_readback_are_provisional
    [@baseline, @candidate].each do |arm|
      arm.first['fingerprint']['execution_framework'] = { 'name' => 'Harbor', 'version' => '0.24.0' }
    end
    result = comparison
    assert_equal 'provisional', result.fetch('status')
    assert_includes result.fetch('provisional_fields'), 'execution_framework'
  end

  def test_a_changed_separate_verifier_image_refuses_even_the_tier_axis
    before = container_readbacks
    after = container_readbacks
    after.last['Image'] = "sha256:#{'b' * 64}"
    set_frameworks(before, after)
    result = comparison('tier')
    assert_equal 'refused', result['status']
    assert_equal ['execution_framework'], result['mismatches']
    refute_includes JSON.generate(result), 'private-id'
  end

  def test_matching_container_evidence_is_eligible
    set_frameworks(container_readbacks, container_readbacks)
    assert_equal 'eligible', comparison['status']
  end

  private

  def set_frameworks(before, after)
    [@baseline, @candidate].zip([before, after]).each do |arm, rows|
      arm.first['fingerprint']['execution_framework'] = {
        'name' => 'Harbor', 'version' => '0.24.0',
        'environment_digest' => Shaka::Evaluation::HarborEnvironment.capture(rows, name: 'shaka-synthetic')['digest']
      }
    end
  end
end
