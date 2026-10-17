# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'reviewer_command_fixture'
require 'shaka/doctor/cli_inventory'

class ReviewerSetupTest < Minitest::Test
  include ReviewerCommandFixture

  def test_skips_reviewers_this_machine_lacks_and_reports_why
    with_repository do |root|
      marker = File.join(root, 'launched')
      result = missing_setup_selection(root, marker)
      assert_equal 'same_model', result.fetch('outcome')
      assert_equal ['openai/codex'], result.fetch('reviewers')
      assert_equal(['not set up on this machine'] * 2, result.fetch('considered').map { |row| row.fetch('reason') })
      assert_setup_notices(result.fetch('setup_notices'))
      refute_path_exists marker
    end
  end

  def test_a_listed_reviewer_joins_once_this_machine_has_it
    with_repository do |root|
      Dir.mktmpdir do |tools|
        rewrite_reviewers(root, missing_setup_agents)
        write_reviewer_tool(tools, File.join(root, 'launched'))
        without_key = selection_with_path(root, "#{tools}:/usr/bin:/bin", '--count', '2')
        with_key = selection_with_path(root, "#{tools}:/usr/bin:/bin", '--count', '2', key: 'test-key')
        assert_equal ['anthropic/claude'], without_key.fetch('reviewers')
        assert_equal %w[deepseek/openrouter anthropic/claude], with_key.fetch('reviewers')
      end
    end
  end

  def test_an_installed_configured_reviewer_needs_no_setup_notice_or_launch
    with_repository do |root|
      Dir.mktmpdir do |tools|
        marker = File.join(root, 'launched')
        rewrite_reviewers(root, [{ 'provider' => 'anthropic', 'model_family' => 'claude' }])
        write_reviewer_tool(tools, marker)
        result = selection_with_path(root, "#{tools}:/usr/bin:/bin")
        assert_empty result.fetch('setup_notices')
        refute_path_exists marker
      end
    end
  end

  # A lookup that could not be checked is left to the review run to report.
  def test_keeps_a_reviewer_whose_lookup_could_not_be_checked
    entries = [{ identity: 'openai/codex', configured: true, installed: false, unchecked: true },
               { identity: 'deepseek/openrouter', configured: true, installed: false }]
    assert_equal [{ 'provider' => 'deepseek', 'model_family' => 'openrouter' }],
                 Shaka::Doctor::CliInventory.not_set_up(entries)
  end

  private

  def missing_setup_selection(root, marker)
    rewrite_reviewers(root, missing_setup_agents)
    write_reviewer_tool("#{root}/tools", marker)
    selection_with_path(root, "#{root}/tools:/usr/bin:/bin")
  end

  def selection_with_path(root, path, *, key: nil)
    env = { 'SHAKA_RUBY' => RbConfig.ruby, 'PATH' => path, 'OPENROUTER_API_KEY' => key }
    output, error, status = Open3.capture3(env, COMMAND, 'reviewer', '--root', root,
                                           '--implementer', 'openai/codex', *)
    assert_predicate status, :success?, error
    JSON.parse(output)
  end

  def write_reviewer_tool(directory, marker)
    FileUtils.mkdir_p(directory)
    path = File.join(directory, 'claude')
    File.write(path, "#!/bin/sh\ntouch #{marker}\n")
    File.chmod(0o700, path)
  end

  def missing_setup_agents
    [{ 'provider' => 'deepseek', 'model_family' => 'openrouter',
       'model' => 'deepseek/deepseek-v4.1-flash', 'effort' => 'low' },
     { 'provider' => 'anthropic', 'model_family' => 'claude' }]
  end

  def assert_setup_notices(notices)
    assert_equal(%w[anthropic/claude deepseek/openrouter], notices.map { |notice| notice.fetch('reviewer') }.sort)
    assert_includes notices.find { |notice| notice['reviewer'] == 'deepseek/openrouter' }.fetch('guidance'),
                    'OPENROUTER_API_KEY'
  end
end
