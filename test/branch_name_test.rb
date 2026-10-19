# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'shaka/branch_name'

class BranchNameTest < Minitest::Test
  def test_rejects_names_git_resolves_through_refs_first
    with_git_repository(ignorecase: false) do |root|
      %w[heads/main tags/v1 remotes/origin/main Heads/main REFS/heads/main].each do |value|
        error = assert_raises(Shaka::Error) { explicit!(value, root) }

        assert_includes error.message, 'base_branch must be a branch name, not a qualified ref'
      end
    end
  end

  def test_accepts_those_words_below_the_top_level
    with_git_repository(ignorecase: false) do |root|
      %w[feature/heads/main release/tags/v1 headsup/main].each do |value|
        assert_equal value, explicit!(value, root)
      end
    end
  end

  def test_rejects_root_refs_in_any_case_when_git_ignores_case
    with_git_repository(ignorecase: true) do |root|
      %w[head Head fetch_head orig_head auto_merge merge_autostash bisect_expected_rev].each do |value|
        error = assert_raises(Shaka::Error) { explicit!(value, root) }

        assert_includes error.message, 'base_branch must be a branch name, not a Git root ref'
      end
    end
  end

  def test_accepts_ordinary_lowercase_names_when_git_ignores_case
    with_git_repository(ignorecase: true) do |root|
      %w[main release trunk headless config].each do |value|
        assert_equal value, explicit!(value, root)
      end
    end
  end

  def test_accepts_lowercase_root_ref_names_when_git_respects_case
    with_git_repository(ignorecase: false) do |root|
      %w[head fetch_head].each do |value|
        assert_equal value, explicit!(value, root)
      end
    end
  end

  private

  def explicit!(value, root)
    Shaka::BranchName.explicit!(value, label: 'base_branch', root:)
  end

  def with_git_repository(ignorecase:)
    Dir.mktmpdir('shaka-branch-name') do |root|
      git(root, 'init', '-q')
      git(root, 'config', 'core.ignorecase', ignorecase.to_s)
      yield root
    end
  end

  def git(root, *)
    system('git', '-C', root, *, exception: true)
  end
end
