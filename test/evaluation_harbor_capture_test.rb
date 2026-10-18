# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/harbor_trial'
require_relative 'support/evaluation_budget_fixture'
require_relative 'support/evaluation_harbor_fixture'

class EvaluationHarborCaptureTest < Minitest::Test
  include EvaluationBudgetFixture
  include EvaluationHarborFixture

  def test_native_readback_replaces_the_builders_framework_fingerprint
    setup_harbor
    harbor_run
    framework = saved_harbor_record.dig('fingerprint', 'execution_framework')
    assert_equal 'Harbor', framework['name']
    assert_equal '0.24.0', framework['version']
    assert_equal @capture.dig('environment', 'digest'), framework['environment_digest']
    assert_match(/\Asha256:[a-f0-9]{64}\z/, framework['environment_digest'])
  end

  def test_capture_keeps_only_image_identity_from_docker_inspection
    setup_harbor
    harbor_run
    assert_equal 2, @capture.fetch('images').size
    assert_equal %w[image_digest project], @capture.fetch('images').first.keys
  end

  def test_repeated_trials_with_truncated_verifier_project_names_match
    setup_harbor
    assert_equal 'complete', harbor_run(count: 2)['status']
    digests = saved_records.map do |path|
      JSON.parse(File.read(path)).dig('fingerprint', 'execution_framework', 'environment_digest')
    end
    assert_equal 1, digests.uniq.length
  end
end
