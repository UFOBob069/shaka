# frozen_string_literal: true

require_relative 'install_scenario_support'

# Source checkouts Shaka no longer supports: status names one command that replaces each one.
class InstallStatusUnsupportedTest < Minitest::Test
  include InstallScenarioSupport

  # The reinstall step must work: afterward the old checkout's record is the only thing left to retire.
  def test_the_reinstall_step_replaces_the_old_location
    old = clone_to(File.join(@home, '.agents/shaka'))
    run_install(old, '--directory', old, '--repository', @remote, '--agent', 'claude', '--with-rct')
    run_step(status(old), 'E1')
    report = status(default_path)
    assert_equal ['C1', File.realpath(old)], report.values_at('state', 'location')
    assert_equal File.join(File.realpath(default_path), 'skills/rct'),
                 File.realpath(File.join(@home, '.claude/skills/rct'))
  end

  def test_a_source_checkout_that_is_a_linked_worktree_is_replaced
    git('-C', @root, 'worktree', 'add', '-q', File.join(@directory, 'feature-tree'))
    link = File.join(@home, '.claude/skills/shaka')
    FileUtils.mkdir_p(File.dirname(link))
    File.symlink(File.join(@directory, 'feature-tree/skills/shaka'), link)
    report = status(@root)
    assert_equal 'C3', report['state']
    assert_includes report['next_command'], "rm -- #{Shellwords.escape(link)} && "
    assert_includes report['next_command'], '--agent claude'
  end

  # One command would give every host the union of their towers, so differing hosts get a decision.
  def test_hosts_with_different_towers_get_a_decision
    old = clone_to(File.join(@home, '.agents/shaka'))
    run_install(old, '--directory', old, '--repository', @remote, '--agent', 'claude')
    run_install(old, '--agent', 'codex', '--with-rct')
    report = status(old)
    assert_equal 'E1', report['state']
    assert_includes report['decision'], 'one bin/install run per host'
  end

  def test_an_existing_default_directory_gets_a_decision
    old = clone_to(File.join(@home, '.agents/shaka'))
    run_install(old, '--directory', old, '--repository', @remote)
    FileUtils.mkdir_p(File.join(default_path, 'leftover'))
    report = status(old)
    assert_equal ['E1', nil], report.values_at('state', 'next_command')
  end

  private

  def run_step(report, state)
    assert_equal state, report['state']
    output, process = Open3.capture2e(environment, 'sh', '-c', report['next_command'])
    assert_predicate process, :success?, output
  end
end
