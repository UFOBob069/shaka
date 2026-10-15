# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require_relative '../skills/shaka/lib/shaka/local_review/rebased_commits'
require_relative '../skills/shaka/lib/shaka/local_review/summary'

# A reviewed commit rebased before it was pushed links to its pushed copy, and only to a commit
# making the same change.
class LocalReviewRebasedCommitsTest < Minitest::Test
  DATE = '2026-10-13T22:10:00-07:00'
  PULL = Struct.new(:commits) do
    def number = 7

    def api_list(path)
      raise "unexpected #{path}" unless path == 'repos/o/r/pulls/7/commits?per_page=100'

      commits
    end
  end

  def setup
    @root = Dir.mktmpdir
    git('init', '--quiet')
    @base = commit('a.txt', "base\n", 'Start')
    @reviewed = commit('x.txt', "reviewed\n", 'Add review publication', date: DATE)
    git('checkout', '--quiet', '--detach', @base)
    commit('a.txt', "moved\n", 'Move main')
    @copy = identity('cherry-pick', @reviewed)
  end

  def teardown = FileUtils.remove_entry(@root)

  def test_the_commit_with_the_same_subject_date_and_change_is_the_copy
    assert_equal @copy, rebased([pushed(@base), pushed(@copy)]).call(@reviewed)
  end

  def test_an_amended_commit_with_new_content_is_not_a_copy
    git('checkout', '--quiet', '--detach', @copy)
    amended = commit('x.txt', "changed\n", 'Add review publication', date: DATE, amend: true)

    assert_nil rebased([pushed(amended)]).call(@reviewed)
  end

  def test_an_amended_commit_changing_only_whitespace_is_not_a_copy
    git('checkout', '--quiet', '--detach', @copy)
    amended = commit('x.txt', "reviewed \n", 'Add review publication', date: DATE, amend: true)

    assert_nil rebased([pushed(amended)]).call(@reviewed)
  end

  def test_an_amended_binary_change_is_not_a_copy
    git('checkout', '--quiet', '--detach', @copy)
    File.binwrite(File.join(@root, 'x.txt'), "\x00\x01binary")
    git('add', 'x.txt')
    binary = identity('commit', '--quiet', '--amend', '-m', 'Add review publication', date: DATE)

    assert_nil rebased([pushed(binary)]).call(binary)
  end

  def test_no_copy_without_the_local_commit_or_a_readable_list
    assert_nil rebased([pushed(@copy)]).call('d' * 40)
    failing = Object.new
    def failing.number = 7
    def failing.api_list(_path) = raise(Shaka::Error, 'GitHub API response has an unexpected type.')

    assert_nil Shaka::LocalReviewRebasedCommits.new(failing, 'o/r', root: @root).call(@reviewed)
  end

  def test_a_link_names_the_reviewed_commit_and_opens_its_copy
    links = Shaka::LocalReviewLinks.new('o/r', ->(_) { false }, ->(_) { 'b' * 40 })

    assert_equal "`#{@reviewed[0, 7]}`, rebased as [`bbbbbbb`](https://github.com/o/r/commit/#{'b' * 40})",
                 links.commit(@reviewed)
    assert_equal "`#{@reviewed[0, 7]}` (not on GitHub)",
                 Shaka::LocalReviewLinks.new('o/r', ->(_) { false }, ->(_) {}).commit(@reviewed)
  end

  private

  def rebased(commits) = Shaka::LocalReviewRebasedCommits.new(PULL.new(commits), 'o/r', root: @root)

  # GitHub reports the author date in UTC.
  def pushed(sha)
    message, date = git('log', '-1', '--format=%B%x00%aI', sha).split("\0")
    { 'sha' => sha,
      'commit' => { 'message' => message, 'author' => { 'date' => Time.iso8601(date.strip).utc.iso8601 } } }
  end

  def commit(file, text, subject, date: nil, amend: false)
    File.write(File.join(@root, file), text)
    git('add', file)
    identity('commit', '--quiet', *(amend ? ['--amend'] : []), '-m', subject, date:)
  end

  def identity(*, date: nil)
    env = date ? { 'GIT_AUTHOR_DATE' => date } : {}
    git('-c', 'user.name=Reviewer', '-c', 'user.email=r@example.test', *, env:)
    git('rev-parse', 'HEAD').strip
  end

  def git(*, env: {})
    output, error, status = Open3.capture3(env, 'git', '-C', @root, *)
    raise error unless status.success?

    output
  end
end
