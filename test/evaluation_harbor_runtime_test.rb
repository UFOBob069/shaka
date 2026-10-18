# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/harbor_trial'
require_relative 'support/evaluation_budget_fixture'
require_relative 'support/evaluation_harbor_fixture'

class EvaluationHarborRuntimeTest < Minitest::Test
  include EvaluationBudgetFixture
  include EvaluationHarborFixture

  def test_rejects_api_key_bearing_codex_credentials
    setup_harbor
    File.write(@credential, JSON.generate({ 'tokens' => { 'access_token' => 'synthetic-token' },
                                            'OPENAI_API_KEY' => 'synthetic-api-key' }))
    tools = { 'harbor' => File.join(@bin, 'harbor'), 'source' => @source, 'docker' => File.join(@bin, 'docker') }
    profile = { 'host' => 'codex', 'model' => 'synthetic', 'version' => '1.2.3',
                'reasoning_effort' => 'medium', 'timeout_seconds' => 1 }
    assert_raises(ArgumentError) do
      Shaka::Evaluation::HarborRuntime.new(tools: tools, credential: @credential, skill: @skill, profile: profile)
    end
  end

  def test_controller_environment_and_config_exclude_inherited_credentials
    setup_harbor
    with_controller_secrets { harbor_run }
    environment = observed_harbor.fetch('env')
    %w[OPENAI_API_KEY ANTHROPIC_API_KEY GITHUB_TOKEN HTTPS_PROXY CLAUDE_CODE_OAUTH_TOKEN].each do |key|
      refute environment.key?(key)
    end
    assert_equal 'off', environment['HARBOR_TELEMETRY']
    assert_equal '1', environment['PYTHON_DOTENV_DISABLED']
    assert_equal environment['HOME'], observed_harbor['cwd']
  end

  def test_credential_copy_is_private_and_removed
    setup_harbor
    harbor_run
    assert_equal 0o600, observed_harbor['credential_mode']
    refute_path_exists observed_harbor.fetch('env').fetch('CODEX_AUTH_JSON_PATH')
  end

  def test_native_config_pins_cli_and_uses_the_tested_adapter
    setup_harbor
    harbor_run
    config = observed_harbor.fetch('config')
    assert_equal '1.2.3', config.dig('agent', 'kwargs', 'version')
    assert config.dig('environment', 'kwargs', 'keep_containers')
    assert_equal 'capability_upload:CapabilityUploadDocker', config.dig('environment', 'import_path')
    refute_includes JSON.generate(config), 'private-subscription-secret'
  end

  def test_claude_uses_only_selected_subscription
    setup_harbor(host: 'claude-code')
    harbor_run
    environment = observed_harbor.fetch('env')
    assert_equal '1', environment['CLAUDE_FORCE_OAUTH']
    assert_equal 'private-subscription-secret', environment['CLAUDE_CODE_OAUTH_TOKEN']
    refute environment.key?('CODEX_AUTH_JSON_PATH')
  end

  def test_invalid_tasks_and_unpinned_runtime_fail_before_reserving
    setup_harbor
    account = budget
    assert_raises(ArgumentError) { harbor_trial.run(tasks, budget: account, records: @directory) { flunk } }
    fake_executable('harbor', "puts '0.25.0'")
    assert_raises(ArgumentError) { harbor_run(account) }
    assert_equal 0, account.snapshot['pending']
    refute_path_exists File.join(@directory, 'observed.json')
  end

  def test_a_different_docker_on_path_fails_before_reserving
    selected = File.join(@directory, 'selected-docker')
    File.write(selected, "#!/bin/sh\nexit 77\n")
    File.chmod(0o755, selected)
    setup_harbor(docker: selected)
    account = budget
    error = assert_raises(ArgumentError) { harbor_run(account) }
    assert_includes error.message, 'Docker'
    assert_equal 0, account.snapshot['pending']
    refute_path_exists File.join(@directory, 'observed.json')
  end
end
