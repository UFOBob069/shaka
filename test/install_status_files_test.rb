# frozen_string_literal: true

require_relative 'install_scenario_support'

# Skill files installation would refuse, including changes Git does not show: each gets a step that fixes it.
class InstallStatusFilesTest < Minitest::Test
  include InstallScenarioSupport

  def test_a_writable_skill_file_is_unsafe
    root = default_install
    File.chmod(0o664, File.join(root, 'skills/shaka/SKILL.md'))
    report = status(root)
    assert_equal 'B10', report['state']
    assert_includes report['next_command'], 'chmod -R go-w'
  end

  # Installation refuses a symlink in a skill, and chmod cannot fix one, so status asks to move it.
  def test_a_symlink_in_a_skill_is_named
    root = default_install
    link = File.join(root, 'skills/shaka/alias.md')
    File.symlink('SKILL.md', link)
    report = status(root)
    assert_equal ['B10', nil], report.values_at('state', 'next_command')
    assert_includes report['decision'], 'alias.md'
  end

  # Git ignores a 0644 to 0600 change, but verification refuses it, so status must not call it healthy.
  def test_a_mode_change_git_ignores_is_named
    root = default_install
    File.chmod(0o600, File.join(root, 'skills/shaka/SKILL.md'))
    report = status(root)
    assert_equal ['B3', nil], report.values_at('state', 'next_command')
    assert_includes report['decision'], 'rerun bin/install'
  end

  # With core.filemode=false Git hides a lost execute bit, but installation refuses it, so status names it.
  def test_a_helper_that_lost_its_execute_bit_is_named
    root = default_install
    git('-C', root, 'config', 'core.filemode', 'false')
    File.chmod(0o644, File.join(root, 'skills/shaka/scripts/shaka'))
    report = status(root)
    assert_equal 'B10', report['state']
    output, process = Open3.capture2e(environment, 'sh', '-c', report['next_command'])
    assert_predicate process, :success?, output
    assert_equal 'A1', status(root)['state']
  end

  def test_a_setuid_skill_file_is_unsafe
    root = default_install
    File.chmod(0o4644, File.join(root, 'skills/shaka/SKILL.md'))
    report = status(root)
    assert_equal 'B10', report['state']
    assert_includes report['next_command'], 'chmod -R a-st'
  end
end
