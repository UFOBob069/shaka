# frozen_string_literal: true

require_relative 'startup_notice_support'

class StartupLinkNoticeTest < Minitest::Test
  include StartupNoticeSupport

  def test_names_the_installation_a_host_link_points_to
    link('.claude/skills', @root)
    development = checkout('development clone', registered: false)
    expected = "shaka: This helper runs from #{development}, but #{File.join(@home, '.claude/skills/shaka')} " \
               "links to #{@root}. Use #{@root}/skills/shaka/scripts/shaka."
    assert_equal expected, notice(root: development)
  end

  def test_linked_helper_trial_package_and_unlinked_machine_get_no_link_notice
    development = checkout('development', registered: false)
    assert_nil notice(root: development)
    link('.agents/skills', development)
    assert_nil notice(root: development)
    trial = checkout('trial', registered: false)
    File.write(File.join(trial, '.shaka-install.json'), '{}')
    assert_nil notice(root: trial)
  end

  def test_helper_prints_the_link_notice_and_runs_no_command
    link('.claude/skills', @root)
    path = "#{fake_commands}:#{File.dirname(RbConfig.ruby)}"
    _output, error, status = Open3.capture3({ 'HOME' => @home, 'PATH' => path, 'SHAKA_NOTICES' => nil },
                                            COMMAND, 'workflow', '--help')
    assert_predicate status, :success?, error
    assert_match(/\Ashaka: This helper runs from .* links to #{Regexp.escape(@root)}\./, error)
    refute_path_exists ran
  end
end
