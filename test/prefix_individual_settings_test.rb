# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'configuration_layout_fixture'
require 'shaka/prefix'
require 'json'

class PrefixIndividualSettingsTest < Minitest::Test
  include ConfigurationLayoutFixture

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_complete_individual_settings_supply_the_prefix
    with_individual_settings('repo_prefix' => 'CPF') do |root, ref|
      assert_equal({ 'prefix' => 'CPF', 'source' => 'individual' }, prefix(root, ref))
    end
  end

  def test_complete_individual_settings_without_a_prefix_use_the_fallback
    with_individual_settings do |root, ref|
      assert_equal 'fallback', prefix(root, ref).fetch('source')
    end
  end

  def test_partial_individual_settings_keep_the_fallback
    with_individual_settings('repo_prefix' => 'CPF') do |root, ref|
      File.delete(File.join(root, '.agents/shaka/bin/test'))
      assert_equal 'fallback', prefix(root, ref).fetch('source')
    end
  end

  def test_an_invalid_individual_prefix_keeps_the_fallback
    with_individual_settings('repo_prefix' => 'shop') do |root, ref|
      assert_equal 'fallback', prefix(root, ref).fetch('source')
    end
  end

  def test_shared_settings_take_precedence_over_the_working_tree
    with_individual_settings('repo_prefix' => 'TEAM') do |root, _ref|
      ref = commit(root, '.agents')
      path = File.join(root, '.agents/shaka/config.yml')
      File.write(path, File.read(path).sub('TEAM', 'LOCAL'))
      assert_equal({ 'prefix' => 'TEAM', 'source' => 'seam' }, prefix(root, ref))
    end
  end

  def test_a_branch_that_commits_settings_does_not_supply_an_individual_prefix
    with_individual_settings('repo_prefix' => 'CAND') do |root, ref|
      commit(root, '.agents')
      assert_equal 'fallback', prefix(root, ref).fetch('source')
    end
  end

  def test_a_subdirectory_root_keeps_the_fallback
    with_individual_settings('repo_prefix' => 'CPF') do |root, ref|
      subdirectory = File.join(root, 'sub')
      FileUtils.mkdir_p(subdirectory)
      assert_equal({ 'prefix' => 'SUB', 'source' => 'fallback' }, prefix(subdirectory, ref))
    end
  end

  def test_repos_refresh_catalogs_the_individual_prefix
    with_individual_settings('repo_prefix' => 'CPF') do |root, _ref|
      git!(root, 'remote', 'add', 'origin', 'https://github.com/acme/solo.git')
      git!(root, 'update-ref', 'refs/remotes/origin/main', 'HEAD')
      git!(root, 'symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/main')
      row = Dir.mktmpdir('shaka-repos-home') { |home| refreshed_row(home, root) }
      assert_equal %w[CPF individual], row.values_at('prefix', 'prefix_source')
    end
  end

  private

  def refreshed_row(home, root)
    env = { 'SHAKA_HOME' => home, 'PATH' => ENV.fetch('PATH') }
    [%w[add --root] + [root], %w[refresh]].each do |arguments|
      _output, error, status = Open3.capture3(env, COMMAND, 'repos', *arguments)
      raise error unless status.success?
    end
    JSON.parse(File.read(File.join(home, 'catalog.json'))).fetch('repositories').first
  end

  def prefix(root, ref) = Shaka::Prefix.new(root:, ref:).call

  def with_individual_settings(extra = {})
    Dir.mktmpdir('shaka-prefix-individual') do |root|
      git!(root, 'init', '--quiet')
      File.write(File.join(root, 'README.md'), "project\n")
      ref = commit(root, 'README.md')
      FileUtils.mkdir_p(File.join(root, '.agents/shaka/bin'))
      create_new_commands(root)
      File.write(File.join(root, '.agents/shaka/config.yml'), YAML.dump(config.merge(extra)))
      yield root, ref
    end
  end

  def commit(root, path)
    git!(root, 'add', path)
    git!(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '--quiet', '-m', path)
    Open3.capture2('git', '-C', root, 'rev-parse', 'HEAD').first.strip
  end

  def git!(root, *)
    output, status = Open3.capture2e('git', '-C', root, *)
    raise output unless status.success?
  end
end
