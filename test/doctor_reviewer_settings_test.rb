# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'
require_relative 'repository_fixture'

# Doctor checks every reviewer a repository configures, not only the local code reviewers.
class DoctorReviewerSettingsTest < Minitest::Test
  include DoctorHelper
  include RepositoryConfigTestHelpers

  def test_an_opening_check_effort_claude_rejects_fails
    report, blocked = doctor_with('pr_description' => opening('effort' => 'turbo'))

    assert_includes report, '[FAILED] Reviewer settings'
    assert_includes report, 'Opening check: anthropic/claude effort `turbo`'
    assert blocked
  end

  def test_an_unknown_checkpoint_model_warns
    report, blocked = doctor_with('review' => checkpoint('model' => 'claude-opus-5-6'))

    assert_includes report, '[DEGRADED] Reviewer settings'
    assert_includes report, 'Checkpoint: anthropic/claude model `claude-opus-5-6`'
    refute blocked
  end

  def test_a_checkpoint_reviewer_without_a_model_does_not_inherit_the_default_model
    report, = doctor_with('review' => checkpoint('model' => nil))

    assert_includes report, '[HEALTHY] Reviewer settings'
  end

  def test_disabled_checks_are_not_reported
    report, = doctor_with('pr_description' => opening('effort' => 'turbo', 'enabled' => false),
                          'review' => checkpoint('model' => 'claude-opus-5-6', 'enabled' => false))

    assert_includes report, '[HEALTHY] Reviewer settings'
  end

  private

  def opening(settings)
    { 'opening_check' => { 'reviewer' => 'anthropic/claude' }.merge(settings) }
  end

  # A Claude checkpoint keeps these tests independent of which Codex models the catalog lists.
  def checkpoint(settings)
    review_policy('post_implementation' => { 'reviewer' => 'anthropic/claude' }.merge(settings).compact)
  end

  def doctor_with(sections)
    report = nil
    blocked = nil
    with_repository(sections) { |root| report, blocked = doctor(root:) }
    [report, blocked]
  end
end
