# frozen_string_literal: true

require_relative 'test_helper'

class CliOpeningFlagsTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_reviewer_flag_only_applies_to_descriptions
    _output, error, status = Open3.capture3(COMMAND, 'pr', 'owner/repo', '1',
                                            '--opening-reviewer', 'anthropic/claude')
    refute_predicate status, :success?
    assert_includes error, '--opening-reviewer is only for description'
  end

  def test_model_flag_requires_a_reviewer
    _output, error, status = Open3.capture3(COMMAND, 'description', 'owner/repo', '1',
                                            '--opening-model', 'model-name')
    refute_predicate status, :success?
    assert_includes error, '--opening-model requires --opening-reviewer'
  end

  def test_effort_flag_requires_a_reviewer
    _output, error, status = Open3.capture3(COMMAND, 'description', 'owner/repo', '1', '--opening-effort', 'high')
    refute_predicate status, :success?
    assert_includes error, '--opening-effort requires --opening-reviewer'
  end

  def test_malformed_reviewer_with_a_model_is_a_usage_error
    _output, error, status = Open3.capture3(COMMAND, 'description', 'owner/repo', '1',
                                            '--opening-reviewer', 'claude', '--opening-model', 'named-model')
    refute_predicate status, :success?
    assert_includes error, 'Reviewer identity must be PROVIDER/MODEL_FAMILY'
  end
end
