# frozen_string_literal: true

require_relative 'test_helper'

# Hosted validate failed when Git's background maintenance removed .git/objects/maintenance.lock
# while Dir.mktmpdir was deleting a fixture repository.
class TestGitMaintenanceTest < Minitest::Test
  def test_fixture_repositories_never_start_background_maintenance
    Dir.mktmpdir('shaka-maintenance') do |root|
      output, status = Open3.capture2e(TEST_GIT, 'init', '--quiet', root)
      assert_predicate status, :success?, output

      assert_equal(%w[false 0], %w[maintenance.auto gc.auto].map { |key| config(root, key) })
    end
  end

  def test_an_explicit_global_config_is_kept_alone
    assert_equal ['/explicit'], TestGitConfig.own_files('GIT_CONFIG_GLOBAL' => '/explicit', 'HOME' => '/home')
  end

  # Git reads the XDG file first, so ~/.gitconfig wins a conflict.
  def test_default_files_keep_gits_order
    assert_equal %w[~/.config/git/config ~/.gitconfig], TestGitConfig.own_files({})
    assert_equal %w[/xdg/git/config ~/.gitconfig], TestGitConfig.own_files('XDG_CONFIG_HOME' => '/xdg')
  end

  # Install tests point HOME at a temporary directory; that home's config must still apply.
  def test_a_changed_home_still_supplies_its_own_config
    Dir.mktmpdir('shaka-home') do |home|
      File.write(File.join(home, '.gitconfig'), "[user]\n\tname = Fake Home\n")
      File.write(File.join(home, 'config'), TestGitConfig.text({}))
      env = { 'HOME' => home, 'XDG_CONFIG_HOME' => nil, 'GIT_CONFIG_GLOBAL' => File.join(home, 'config') }
      output, = Open3.capture2e(env, TEST_GIT, '-C', home, 'config', '--get', 'user.name')

      assert_equal 'Fake Home', output.strip
    end
  end

  def test_a_developer_setting_survives_and_maintenance_still_wins
    Dir.mktmpdir('shaka-own-config') do |dir|
      own = File.join(dir, 'own')
      File.write(own, "[user]\n\tname = Developer\n[gc]\n\tauto = 50\n")
      File.write(File.join(dir, 'config'), TestGitConfig.text('GIT_CONFIG_GLOBAL' => own))

      assert_equal(%w[Developer 0], %w[user.name gc.auto].map { |key| config(dir, key, File.join(dir, 'config')) })
    end
  end

  def test_a_path_with_comment_characters_is_still_included
    Dir.mktmpdir('shaka-#own;config') do |dir|
      own = File.join(dir, 'own "config"')
      File.write(own, "[user]\n\tname = Developer\n")
      File.write(File.join(dir, 'config'), TestGitConfig.text('GIT_CONFIG_GLOBAL' => own))

      assert_equal 'Developer', config(dir, 'user.name', File.join(dir, 'config'))
    end
  end

  def config(root, key, global = ENV.fetch('GIT_CONFIG_GLOBAL'))
    output, = Open3.capture2e({ 'GIT_CONFIG_GLOBAL' => global }, TEST_GIT, '-C', root, 'config', '--get', key)
    output.strip
  end
end
