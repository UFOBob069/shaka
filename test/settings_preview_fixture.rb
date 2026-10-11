# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/evidence/inputs'

module SettingsPreviewFixture
  include RepositoryConfigTestHelpers

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  private

  def capture(root, ref)
    Shaka::Evidence::Inputs.capture(root:, ref:, repository: 'owner/repo')[1]
  end

  def select_preview(root, source)
    output, error, status = Open3.capture3(COMMAND, 'seam', 'preview', 'start', '--root', root,
                                           '--settings-ref', source)
    assert_predicate status, :success?, error
    assert_equal 'active', JSON.parse(output)['status']
  end

  def with_preview_repository(layout: :legacy)
    with_repository('merge' => { 'preference' => 'ask', 'required_checks' => ['trusted-gate'] }) do |root|
      use_new_layout(root) if layout == :new
      git(root, 'init', '-q', '-b', 'main')
      trusted = commit(root)
      git(root, 'checkout', '-qb', 'settings')
      preview = create_preview_commit(root)
      git(root, 'checkout', '-qb', 'feature', trusted)
      yield root, trusted, preview
    end
  end

  def create_preview_commit(root, model: 'preview-model')
    data = seam('merge' => { 'preference' => 'auto' })
    data['review']['local_review_agents'] = [{ 'provider' => 'openai', 'model_family' => 'codex',
                                               'model' => model }]
    write_settings(root, data)
  end

  def settings(root) = YAML.safe_load_file(File.join(root, Shaka::Configuration::Layout.worktree(root:).contract))

  def write_settings(root, data)
    File.write(File.join(root, Shaka::Configuration::Layout.worktree(root:).contract), YAML.dump(data))
    commit(root)
  end

  def remove_trusted_setup(root)
    git(root, 'rm', '-r', '.agents')
    absent = commit(root)
    FileUtils.mkdir_p(File.join(root, '.agents/bin'))
    create_commands(root)
    absent
  end

  def use_new_layout(root)
    FileUtils.mkdir_p(File.join(root, '.agents/shaka'))
    FileUtils.mv(File.join(root, '.agents/bin'), File.join(root, '.agents/shaka/bin'))
    FileUtils.mv(File.join(root, '.agents/agent-workflow.yml'), File.join(root, '.agents/shaka/config.yml'))
  end

  def commit(root)
    git(root, 'add', '.')
    git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-qm', 'fixture')
    git(root, 'rev-parse', 'HEAD').strip
  end

  def git(root, *)
    output, error, status = Open3.capture3('git', '-C', root, *)
    raise error unless status.success?

    output
  end
end
