# frozen_string_literal: true

require_relative 'install_scenario_support'

# Status reached the way people and doctor reach it, and what it must never print.
class InstallStatusEntryTest < Minitest::Test
  include InstallScenarioSupport

  REPOSITORY = File.expand_path('..', __dir__)

  # The installer's current default still counts as a default location until #680 moves it.
  def test_the_current_installer_default_is_a_default_install
    root = clone_to(File.join(@home, '.agents/shaka'))
    git('-C', root, 'remote', 'set-url', 'origin', OFFICIAL)
    run_install(root)
    assert_equal 'A1', status(root)['state']
  end

  def test_a_writable_skill_file_is_unsafe
    root = default_install
    File.chmod(0o664, File.join(root, 'skills/shaka/SKILL.md'))
    report = status(root)
    assert_equal 'B10', report['state']
    assert_includes report['next_command'], 'chmod -R go-w'
  end

  TOKEN_URL = 'https://someone:s3cr@t-token@example.com/shaka.git'

  # A refused update must change nothing, including the recorded Ruby while it still works.
  def test_a_refused_update_keeps_a_working_recorded_ruby
    root = default_install
    record = File.join(root, '.git/shaka-ruby')
    other = File.join(@directory, 'other-ruby')
    File.write(other, "#!/bin/sh\n")
    File.chmod(0o755, other)
    File.write(record, "#{other}\n")
    File.write(File.join(root, 'notes.txt'), 'draft')
    _output, process = Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), '--update')
    refute_predicate process, :success?
    assert_equal "#{other}\n", File.read(record)
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

  def test_a_setuid_skill_file_is_unsafe
    root = default_install
    File.chmod(0o4644, File.join(root, 'skills/shaka/SKILL.md'))
    report = status(root)
    assert_equal 'B10', report['state']
    assert_includes report['next_command'], 'chmod -R a-st'
  end

  # The token holds an @, so redaction must strip up to the last @ before the path, as git does.
  def test_an_origin_token_is_never_printed
    root = default_install
    git('-C', root, 'remote', 'set-url', 'origin', TOKEN_URL)
    output = status_text(root)
    assert_equal 'B5', JSON.parse(output)['state']
    refute_match(/s3cr|t-token/, output)
  end

  def test_a_recorded_token_is_never_printed
    root = default_install
    git('-C', root, 'remote', 'set-url', 'origin', TOKEN_URL)
    record = File.join(root, '.git/shaka-install.json')
    File.write(record, JSON.generate(JSON.parse(File.read(record)).merge('repository' => TOKEN_URL)))
    output = status_text(root)
    assert_equal 'A5', JSON.parse(output)['state']
    refute_match(/s3cr|t-token/, output)
  end

  # A PR trial runs its own helper on purpose, so status from inside one is not an unregistered clone.
  def test_a_helper_inside_a_pr_trial_is_not_unregistered
    default_install
    trial = clone_to(File.join(@home, '.local/share/shaka/pr-trials/123-example'))
    refute_equal 'A9', status(trial)['state']
  end

  # A copy an older installer made is unsupported, not absent: status says where the links point.
  def test_links_into_an_unregistered_copy_are_named
    copy = File.join(@directory, 'old copy')
    FileUtils.mkdir_p(File.join(copy, 'skills/shaka'))
    FileUtils.mkdir_p(File.join(@home, '.claude/skills'))
    File.symlink(File.join(copy, 'skills/shaka'), File.join(@home, '.claude/skills/shaka'))
    report = status(@root)
    assert_equal 'none', report['state']
    assert_includes report['detail'], "#{File.realpath(copy)}, which is not a registered checkout"
  end

  def test_the_documented_helper_reports_a_state
    output, process = Open3.capture2e(environment, File.join(REPOSITORY, 'skills/shaka/scripts/shaka'),
                                      'install', '--status', '--json')
    assert_predicate process, :success?, output
    assert_equal 'none', JSON.parse(output)['state']
  end

  def test_doctor_reads_status_for_its_own_package
    script = 'require "shaka/doctor"; puts Shaka::Doctor::System.default.installation_status.call.fetch("location")'
    output, process = Open3.capture2e(environment, RbConfig.ruby, '-I', File.join(REPOSITORY, 'skills/shaka/lib'),
                                      '-e', script)
    assert_predicate process, :success?, output
    assert_equal File.realpath(REPOSITORY), output.strip
  end

  private

  def status_text(root)
    output, process = run_status(root, '--json')
    assert_predicate process, :success?, output
    output
  end
end
