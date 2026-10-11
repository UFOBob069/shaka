# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'
require_relative 'repository_fixture'

class DoctorReviewersTest < Minitest::Test
  include DoctorHelper
  include RepositoryConfigTestHelpers

  def test_lists_each_configured_cli_and_warns_when_the_requested_count_cannot_run
    report, blocked = with_reviewers(count: 2, available: %w[codex])

    assert_includes report, 'openai/codex: codex on PATH'
    assert_includes report, 'anthropic/claude: claude missing from PATH'
    assert_includes report, '1 provider available; 2 reviewers requested'
    assert_includes report, 'docs/settings.md#add-a-second-reviewer'
    refute blocked
  end

  def test_only_the_implementing_provider_degrades_without_blocking
    report, blocked = with_reviewers(count: 1, available: %w[codex])

    assert_includes report, "Only the current host's provider (openai) is available"
    refute blocked
  end

  def test_two_available_providers_are_healthy
    report, blocked = with_reviewers(count: 2, available: %w[codex claude])

    assert_includes report, '[HEALTHY] Reviewer CLIs'
    refute blocked
  end

  def test_a_missing_configured_api_key_warns_even_when_other_reviewers_meet_the_count
    review = review_policy('local_review_count' => 2, 'local_review_agents' => agents + [deepseek_agent])
    with_repository('review' => review) do |root|
      report, blocked = doctor(root:, executable: ->(*) { true })

      assert_includes report, '[DEGRADED] Reviewer CLIs'
      assert_includes report, 'This repository configures deepseek/openrouter reviews'
      assert_includes report, 'Set OPENROUTER_API_KEY'
      refute_includes report, 'Add a second reviewer'
      refute blocked
    end
  end

  def test_path_lookup_does_not_execute_the_reviewer
    Dir.mktmpdir('shaka-doctor-cli') do |path|
      command = File.join(path, 'codex')
      File.write(command, "#!/bin/sh\ntouch #{path}/ran\n")
      File.chmod(0o700, command)
      resolver = Shaka::Doctor::System.default.executable

      assert resolver.call('codex', path, File.expand_path('..', __dir__))
      refute resolver.call('claude', path, File.expand_path('..', __dir__))
      refute_path_exists File.join(path, 'ran')
    end
  end

  def test_a_configured_identity_without_a_cli_adapter_is_reported
    review = review_policy('local_review_agents' => [{ 'provider' => 'custom', 'model_family' => 'reviewer' }])
    with_repository('review' => review) do |root|
      report, blocked = doctor(root:)
      assert_includes report, 'custom/reviewer: no supported CLI adapter'
      refute blocked
    end
  end

  def test_no_configured_reviewers_keeps_fresh_host_review_healthy
    review = review_policy
    review.delete('local_review_agents')
    with_repository('review' => review) do |root|
      report, blocked = doctor(root:)
      assert_includes report, '[HEALTHY] Reviewer CLIs'
      assert_includes report, 'fresh host review remains available'
      refute blocked
    end
  end

  def test_optional_installed_providers_do_not_satisfy_configured_review_count
    review = review_policy('local_review_count' => 2, 'local_review_agents' => agents)
    with_repository('review' => review) do |root|
      report, blocked = doctor(root:, executable: ->(name, *) { name == 'grok' })

      assert_includes report, '0 providers available; 2 reviewers requested'
      assert_includes report, 'grok on PATH (optional)'
      refute blocked
    end
  end

  private

  def with_reviewers(count:, available:)
    review = review_policy('local_review_count' => count, 'local_review_agents' => agents)
    result = nil
    with_repository('review' => review) do |root|
      result = doctor(root:, host: 'codex', executable: ->(name, _path, _root) { available.include?(name) })
    end
    result
  end

  def agents
    [{ 'provider' => 'openai', 'model_family' => 'codex' },
     { 'provider' => 'anthropic', 'model_family' => 'claude' }]
  end

  def deepseek_agent
    { 'provider' => 'deepseek', 'model_family' => 'openrouter',
      'model' => 'deepseek/deepseek-v4.1-flash', 'effort' => 'low' }
  end
end
