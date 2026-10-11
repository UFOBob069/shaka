# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'

# Opening checks honor explicit model choices without changing code-review settings.
class CliOpeningSettingsTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Maintainers can choose how their PR opening is checked.'

  def test_configured_reviewer_model_and_effort_reach_the_cli
    settings = { 'enabled' => true, 'reviewer' => 'anthropic/claude', 'model' => 'chosen-model', 'effort' => 'high' }
    with_settings(settings) do |root, dir|
      assert_opening(dir, root, 'flagged')
      assert_arguments(dir, 'claude', '--model', 'chosen-model')
      assert_arguments(dir, 'claude', '--effort', 'high')
    end
  end

  def test_enabled_false_disables_the_check
    with_settings('enabled' => false, 'reviewer' => 'anthropic/claude') do |root, dir|
      assert_opening(dir, root, 'disabled')
      refute_path_exists File.join(dir, 'claude-called')
    end
  end

  def test_configured_codex_model_works_without_a_different_provider
    settings = { 'reviewer' => 'openai/codex', 'model' => 'chosen-codex', 'effort' => 'high' }
    with_settings(settings) do |root, dir|
      assert_opening(dir, root, 'passed') { write_fake_codex(dir) }
      assert_arguments(dir, 'codex', '-m', 'chosen-codex')
      assert_arguments(dir, 'codex', '-c', 'model_reasoning_effort="high"')
    end
  end

  def test_candidate_changes_cannot_choose_another_opening_model
    with_settings('reviewer' => 'anthropic/claude', 'model' => 'trusted-model') do |root, dir|
      File.write(File.join(root, '.agents/agent-workflow.yml'),
                 YAML.dump(seam('opening_check' => { 'reviewer' => 'openai/codex', 'model' => 'candidate-model' })))
      assert_opening(dir, root, 'flagged')
      assert_arguments(dir, 'claude', '--model', 'trusted-model')
    end
  end

  def test_legacy_disabled_setting_explains_why_an_explicit_reviewer_was_skipped
    with_settings('external_enabled' => false) do |root, dir|
      output, error, status = run_description(dir, root:, reviewer: 'anthropic/claude')
      assert_predicate status, :success?, error
      result = JSON.parse(output).fetch('opening')
      assert_equal 'host_check', result['status']
      assert_includes result['reason'], 'external_enabled'
      refute_path_exists File.join(dir, 'claude-called')
    end
  end

  private

  def with_settings(settings)
    with_repository('opening_check' => settings) do |root|
      commit(root)
      Dir.mktmpdir { |dir| yield root, dir }
    end
  end

  def assert_opening(dir, root, expected, &)
    output, error, status = run_description(dir, root:, ref: true, &)
    assert_predicate status, :success?, error
    assert_equal expected, JSON.parse(output).dig('opening', 'status')
  end

  def assert_arguments(dir, cli, flag, value)
    arguments = JSON.parse(File.read(File.join(dir, "#{cli}-args.json")))
    assert_includes arguments.each_cons(2).to_a, [flag, value]
  end

  def write_fake_codex(dir)
    sentence = { 'character' => 'Maintainers', 'reader_facing' => true, 'action' => 'choose',
                 'object' => 'settings', 'hidden_actions' => [], 'internal_terms' => [] }
    write_executable(dir, 'codex', <<~RUBY)
      require 'json'
      STDIN.read
      File.write(File.join(ENV.fetch('HOME'), 'codex-args.json'), JSON.generate(ARGV))
      File.write(ARGV[ARGV.index('-o') + 1], #{JSON.generate('sentences' => [sentence]).inspect})
    RUBY
  end
end
