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

  def test_a_worktree_origin_token_is_never_printed
    git('-C', @root, 'remote', 'set-url', 'origin', 'https://someone:secret-token@example.com/shaka.git')
    worktree_links('.claude/skills' => %w[shaka])
    output, process = run_status(@root, '--json')
    assert_predicate process, :success?, output
    assert_equal ['C3', nil], JSON.parse(output).values_at('state', 'next_command')
    refute_includes output, 'secret-token'
  end

  # A --separate-git-dir clone (like a submodule) has a .git file too, but it is not a worktree.
  def test_a_separate_git_dir_clone_is_not_a_worktree
    clone = File.join(@directory, 'separate')
    git('clone', '-q', '--separate-git-dir', File.join(@directory, 'separate.git'), @remote, clone)
    FileUtils.mkdir_p(File.join(@home, '.claude/skills'))
    File.symlink(File.join(clone, 'skills/shaka'), File.join(@home, '.claude/skills/shaka'))
    refute_equal 'C3', status(@root)['state']
  end

  # A worktree on another branch may be a feature branch that goes away, so it gets a decision.
  def test_a_worktree_on_another_branch_gets_a_decision
    git('-C', @root, 'push', '-q', 'origin', 'main:stable')
    git('-C', @root, 'fetch', '-q', 'origin')
    worktree_links({ '.claude/skills' => %w[shaka] }, 'origin/stable')
    assert_equal ['C3', nil], status(@root).values_at('state', 'next_command')
  end

  # The clone names main, so a remote whose default branch is another still gives a main checkout.
  def test_the_reinstall_clones_main_when_the_remote_default_differs
    git('-C', @root, 'push', '-q', 'origin', 'main:stable')
    git('-C', @remote, 'symbolic-ref', 'HEAD', 'refs/heads/stable')
    worktree_links('.claude/skills' => %w[shaka])
    run_step(status(@root), 'C3')
    assert_equal 'main', git('-C', default_path, 'branch', '--show-current').strip
  end

  def test_a_worktree_that_tracks_nothing_gets_a_decision
    worktree_links({ '.claude/skills' => %w[shaka] }, nil)
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
  # The worktree tracks start when given; with start nil its new branch tracks nothing.
  def worktree_links(hosts, start = 'origin/main')
    tree = File.join(@directory, 'feature-tree')
    git('-C', @root, 'worktree', 'add', '-q', '-b', 'feature-tree', tree, *start)
    hosts.each do |directory, names|
      FileUtils.mkdir_p(File.join(@home, directory))
      names.each { |name| File.symlink(File.join(tree, 'skills', name), File.join(@home, directory, name)) }
    end
  end
end
