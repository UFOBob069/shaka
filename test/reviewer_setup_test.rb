# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'reviewer_command_fixture'

class ReviewerSetupTest < Minitest::Test
  include ReviewerCommandFixture

  def test_reports_configured_setup_gaps_without_launching_or_silently_skipping_reviewers
    with_repository do |root|
      marker = File.join(root, 'launched')
      result = missing_setup_selection(root, marker)
      assert_equal 'deepseek/openrouter', result.fetch('reviewer')
      assert_setup_notices(result.fetch('setup_notices'))
      refute_path_exists marker
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

  private

  def missing_setup_selection(root, marker)
    rewrite_reviewers(root, missing_setup_agents)
    write_reviewer_tool("#{root}/tools", marker)
    selection_with_path(root, "#{root}/tools:/usr/bin:/bin")
  end

  def selection_with_path(root, path)
    env = { 'SHAKA_RUBY' => RbConfig.ruby, 'PATH' => path, 'OPENROUTER_API_KEY' => nil }
    output, error, status = Open3.capture3(env, COMMAND, 'reviewer', '--root', root,
                                           '--implementer', 'openai/codex')
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
