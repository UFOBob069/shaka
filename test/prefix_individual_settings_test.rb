# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'configuration_layout_fixture'
require 'shaka/prefix'

class PrefixIndividualSettingsTest < Minitest::Test
  include ConfigurationLayoutFixture

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

  private

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
