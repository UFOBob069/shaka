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

  def test_an_origin_token_is_never_printed
    root = default_install
    git('-C', root, 'remote', 'set-url', 'origin', 'https://someone:secret-token@example.com/shaka.git')
    output, process = run_status(root, '--json')
    assert_predicate process, :success?, output
    assert_equal 'B5', JSON.parse(output)['state']
    refute_includes output, 'secret-token'
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
end
