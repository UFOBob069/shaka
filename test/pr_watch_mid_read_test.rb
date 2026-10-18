# frozen_string_literal: true

require_relative 'comments_fixture'
require_relative 'handoff_helper'
require 'shaka/pr_watch'

# Runs the real status and comment readers over scripted gh responses, so a push or merge
# lands between two of their calls the way it would on GitHub.
class PrWatchMidReadTest < Minitest::Test
  include CommentsFixture

  MOVED = 'c' * 40
  OWNER = HandoffFixtures::WIP.fetch('owner')
  EMPTY = { 'issue_comments' => [], 'review_summaries' => [], 'inline_comments' => [] }.freeze

  def test_push_during_status_read_reports_head_moved
    github = client(snapshot_response, snapshot_response, *required_check_responses,
                    snapshot_response(head: MOVED), snapshot_response(head: MOVED))
    assert_equal 'head_moved', watcher(github).call
  end

  def test_merge_during_comment_only_read_reports_closed
    github = client(snapshot_response, open_pull, *comment_read_responses,
                    snapshot_response(state: 'MERGED'), snapshot_response(state: 'MERGED'))
    assert_equal 'closed', watcher(github, comments_only: true).call
  end

  def test_push_during_comment_only_read_reports_head_moved
    github = client(snapshot_response, open_pull, *comment_read_responses,
                    snapshot_response(head: MOVED), snapshot_response(head: MOVED))
    assert_equal 'head_moved', watcher(github, comments_only: true).call
  end

  def test_merge_during_startup_comment_read_reports_closed
    github = client(snapshot_response, *comment_read_responses,
                    snapshot_response(state: 'MERGED'), snapshot_response(state: 'MERGED'))
    assert_equal 'closed', watcher(github, baseline: nil).call
  end

  def test_read_failure_on_an_unchanged_pr_is_still_an_error
    github = client(snapshot_response, open_pull, *comment_read_responses, snapshot_response,
                    response({ 'private' => false, 'visibility' => 'public' }), snapshot_response)
    error = assert_raises(Shaka::Error) { watcher(github, comments_only: true).call }
    assert_equal 'Repository visibility changed during comment read.', error.message
  end

  private

  def watcher(github, comments_only: false, baseline: EMPTY)
    settings = { baseline:, comments_only:, owner: OWNER, interval: 1, settle: 1, timeout: 1 }
    adapters = { clock: -> { 0 }, sleeper: ->(_seconds) { flunk 'expected a wake during the first poll' },
                 comments: -> { comments_reader(github).call(expected_head: HEAD) } }
    Shaka::PrWatch.new(github, head: HEAD, ci_jobs: [], settings:, adapters:)
  end

  def required_check_responses
    [response([{ 'name' => 'validate', 'state' => 'PENDING', 'bucket' => 'pending' }]), *no_configured_requirements]
  end

  def open_pull
    response({ 'body' => HandoffFixtures.description, 'head' => { 'sha' => HEAD }, 'state' => 'open' })
  end

  # A private repository's read: context, the three comment lists, and review threads.
  def comment_read_responses
    [snapshot_response, repository_response('private'), *comment_responses([], [], []), thread_response([])]
  end
end
