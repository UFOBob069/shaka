# frozen_string_literal: true

require_relative 'official_install_support'

# A source checkout that is also a development clone is refused at install and reported at maintenance.
class OfficialDevelopmentUseTest < Minitest::Test
  include OfficialInstallSupport

  def test_install_refuses_a_checkout_with_a_linked_worktree
    git('-C', @root, 'worktree', 'add', '-q', File.join(@directory, 'feature'), '-b', 'feature')
    output, status = invoke('--directory', @root, '--repository', @remote, '--skills-dir', @skills_dir)
    refute_predicate status, :success?
    assert_includes output, 'linked worktrees'
    assert_includes output, 'local branches: feature'
    assert_includes output, '--directory ~/.local/share/shaka/source'
    refute_includes output, '--take-over'
    refute File.symlink?(@destination)
  end

  def test_every_action_refuses_a_source_that_is_a_linked_worktree
    worktree = File.join(@directory, 'worktree')
    git('-C', @root, 'worktree', 'add', '-q', '--detach', worktree)
    [['--repository', @remote, '--skills-dir', @skills_dir], ['--verify'], ['--update']].each do |flags|
      output, status = invoke('--directory', worktree, *flags)
      refute_predicate status, :success?
      assert_includes output, 'is a linked worktree of'
      assert_includes output, 'git clone '
    end
    refute File.symlink?(@destination)
  end

  def test_reinstalling_a_registered_checkout_with_a_branch_names_take_over
    official_install
    git('-C', @root, 'branch', 'topic')
    output, status = invoke
    refute_predicate status, :success?
    assert_includes output, 'local branches: topic'
    assert_includes output, '--take-over'
  end

  def test_verify_and_update_warn_without_failing
    official_install
    git('-C', @root, 'worktree', 'add', '-q', '--detach', File.join(@directory, 'review'))
    %w[--verify --update].each do |action|
      output, status = invoke(action)
      assert_predicate status, :success?, output
      assert_includes output, 'Warning:'
      assert_includes output, 'linked worktrees'
    end
  end

  def test_a_removed_worktree_directory_is_not_development_use
    official_install
    worktree = File.join(@directory, 'gone')
    git('-C', @root, 'worktree', 'add', '-q', '--detach', worktree)
    FileUtils.rm_rf(worktree)
    output, status = invoke('--verify')
    assert_predicate status, :success?, output
    refute_includes output, 'Warning:'
  end
end
