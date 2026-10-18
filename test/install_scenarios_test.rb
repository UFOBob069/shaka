# frozen_string_literal: true

require_relative 'install_scenario_support'
require_relative 'install_scenario_builders'
require_relative '../skills/shaka/lib/shaka/install/status_states'

# Builds every install state `install --status` names, in a temporary HOME, and checks the state,
# where it was found, and the one next step. A state without a scenario here fails.
class InstallScenariosTest < Minitest::Test
  include InstallScenarioSupport
  include HealthyInstallScenarios
  include BrokenInstallScenarios

  Shaka::Install::StatusStates::STATES.each_key do |id|
    define_method("test_state_#{id}") do
      builder = "build_#{id.downcase}"
      flunk "No install scenario for state #{id}; add #{builder}" unless respond_to?(builder, true)
      expected = send(builder)
      report = status(expected.fetch(:from))
      assert_equal id, report['state'], JSON.pretty_generate(report)
      assert_equal canonical(expected.fetch(:location)), canonical(report['location'])
      assert_one_next_step(report, expected[:next])
    end
  end

  def test_problems_are_named_in_fix_order
    root = default_install
    pull(root)
    File.write(File.join(root, 'notes.txt'), 'draft')
    report = status(root)
    assert_equal 'B3', report['state']
    assert_includes report['findings'].map { |item| item['id'] }, 'B1'
  end

  # A record that still reaches one host keeps working there, so it must not be called an orphan.
  def test_a_record_with_one_moved_link_is_not_an_orphan
    root = default_install('--agent', 'codex', '--agent', 'claude')
    File.unlink(File.join(@home, '.claude/skills/shaka'))
    run_install(@root, '--directory', @root, '--repository', @remote, '--agent', 'claude')
    report = status(root)
    assert_equal 'B9', report['state']
    refute_includes report['findings'].map { |item| item['id'] }, 'C1'
    assert_includes report['decision'], 'Choose which install'
  end

  def test_a_link_to_another_skill_in_the_checkout_is_repointed
    root = default_install('--with-rct')
    link = File.join(@home, '.agents/skills/shaka')
    File.unlink(link)
    File.symlink(File.join(root, 'skills/rct'), link)
    report = status(root)
    assert_equal 'B9', report['state']
    assert_includes report['next_command'],
                    "ln -sfn #{Shellwords.escape(File.join(File.realpath(root), 'skills/shaka'))}"
  end

  def test_a_missing_tracking_ref_is_not_called_a_rewrite
    root = default_install
    git('-C', root, 'update-ref', '-d', 'refs/remotes/origin/main')
    report = status(root)
    refute_includes report['findings'].map { |item| item['id'] }, 'B6'
    assert_includes report['next_command'], 'fetch origin main'
  end

  def test_an_unreadable_record_asks_a_person
    root = default_install
    File.write(File.join(root, '.git/shaka-install.json'), '{')
    report = status(root)
    assert_equal 'C1', report['state']
    assert_nil report['next_command']
    assert_includes report['decision'], 'rename it aside'
  end

  def test_an_unsafe_checkout_gets_no_git_reads
    root = default_install
    File.write(File.join(root, 'notes.txt'), 'draft')
    git('-C', root, 'config', 'core.fsmonitor', "touch #{File.join(@directory, 'ran')}")
    File.chmod(0o775, root)
    report = status(root)
    assert_equal(['B10'], report['findings'].select { |item| item['location'] == File.realpath(root) }.map { it['id'] })
    refute_path_exists File.join(@directory, 'ran')
  end

  def test_status_changes_nothing
    root = default_install
    pull(root)
    before = snapshot
    output, process = run_status(root)
    assert_predicate process, :success?, output
    assert_includes output, 'Shaka install state: B1'
    assert_equal before, snapshot
  end
end
