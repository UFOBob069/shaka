# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'
require_relative 'repository_fixture'

# With review.provider_coverage, readiness checks each covered provider by name, not a count.
class DoctorCoverageTest < Minitest::Test
  include DoctorHelper
  include RepositoryConfigTestHelpers

  # Codex and Grok cover two providers, but neither is the covered anthropic.
  def test_a_covered_provider_without_an_installed_reviewer_warns
    grok = { 'provider' => 'xai', 'model_family' => 'grok', 'model' => 'grok-4.7' }
    review = review_policy('provider_coverage' => %w[anthropic openai], 'local_review_agents' => [agents.first, grok])
    with_repository('review' => review) do |root|
      report, blocked = doctor(root:, executable: ->(*) { true })

      assert_includes report, '[DEGRADED] Reviewer CLIs'
      assert_includes report, 'No configured reviewer is installed for covered provider anthropic.'
      refute blocked
    end
  end

  def test_covered_providers_with_installed_reviewers_are_healthy
    review = review_policy('provider_coverage' => %w[anthropic openai], 'local_review_agents' => agents)
    with_repository('review' => review) do |root|
      report, = doctor(root:, executable: ->(*) { true })

      assert_includes report, '[HEALTHY] Reviewer CLIs'
    end
  end

  # Break caught: with no reviewers configured, readiness returned before checking coverage.
  def test_coverage_without_configured_reviewers_warns_for_each_provider
    review = review_policy('provider_coverage' => %w[anthropic openai]).except('local_review_agents')
    with_repository('review' => review) do |root|
      report, = doctor(root:, executable: ->(*) { true })

      assert_includes report, 'No configured reviewer is installed for covered provider anthropic.'
      assert_includes report, 'No configured reviewer is installed for covered provider openai.'
    end
  end

  private

  def agents
    [{ 'provider' => 'openai', 'model_family' => 'codex' },
     { 'provider' => 'anthropic', 'model_family' => 'claude' }]
  end
end
