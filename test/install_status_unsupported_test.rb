# frozen_string_literal: true

require_relative 'install_scenario_support'

# A source checkout that is a linked worktree is unsupported: status names one command that replaces it.
class InstallStatusUnsupportedTest < Minitest::Test
  include InstallScenarioSupport

  # The reinstall step must work: afterward the hosts use a fresh checkout with the same towers.
  def test_the_reinstall_step_replaces_a_worktree_install
    worktree_links('.claude/skills' => %w[shaka rct])
    run_step(status(@root), 'C3')
    assert_equal 'A5', status(default_path)['state']
    assert_equal tower_in(default_path), File.realpath(File.join(@home, '.claude/skills/rct'))
  end

  # One command would give every host the union of their towers, so differing hosts get a decision.
  def test_hosts_with_different_towers_get_a_decision
    worktree_links('.claude/skills' => %w[shaka], '.agents/skills' => %w[shaka rct])
    report = status(@root)
    assert_equal 'C3', report['state']
    assert_includes report['decision'], 'one bin/install run per host'
  end

  def test_an_existing_default_directory_gets_a_decision
    worktree_links('.claude/skills' => %w[shaka])
    FileUtils.mkdir_p(File.join(default_path, 'leftover'))
    assert_equal ['C3', nil], status(@root).values_at('state', 'next_command')
  end

  private

  def run_step(report, state)
    assert_equal state, report['state']
    output, process = Open3.capture2e(environment, 'sh', '-c', report['next_command'])
    assert_predicate process, :success?, output
  end

  def tower_in(root) = File.join(File.realpath(root), 'skills/rct')

  # Host links into a linked worktree of the fixture checkout, as a manual link or old installer left them.
  def worktree_links(hosts)
    tree = File.join(@directory, 'feature-tree')
    git('-C', @root, 'worktree', 'add', '-q', tree)
    hosts.each do |directory, names|
      FileUtils.mkdir_p(File.join(@home, directory))
      names.each { |name| File.symlink(File.join(tree, 'skills', name), File.join(@home, directory, name)) }
    end
  end
end
