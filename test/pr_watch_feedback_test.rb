# frozen_string_literal: true

require_relative 'pr_watch_test'
require_relative 'handoff_helper'

class PrWatchFeedbackTest < Minitest::Test
  include PrWatchFixtures

  OWNER = HandoffFixtures::WIP.fetch('owner')

  class FeedbackGitHub < PrWatchTest::FakeGitHub
    def repository = 'owner/repo'
    def number = 42

    def api(_path)
      { 'body' => HandoffFixtures.description(HandoffFixtures::WIP.merge('owner' => frame.fetch(:owner, OWNER))),
        'head' => { 'sha' => frame[:pr]['headRefOid'] }, 'state' => frame[:pr]['state'].downcase }
    end

    def required_checks = raise('Feedback watch must not poll check completion')
    def checks = raise('Feedback watch must not poll review jobs')
  end

  def test_terminal_checks_do_not_end_feedback_watch_before_late_owner_review
    packets = [packet, packet('review_summaries', 390), packet('review_summaries', 390)]
    ready = frame(required: [check('validate', 'SUCCESS', 'pass')],
                  checks: [check('claude-review', 'SUCCESS', 'pass')])
    reason, elapsed = watch_feedback([ready, ready, ready], packets)
    assert_equal 'trusted_comment', reason
    assert_equal 2, elapsed
  end

  def test_each_feedback_surface_wakes_once_and_handled_baseline_does_not_repeat
    Shaka::PrWatch::COMMENT_KINDS.each do |kind|
      feedback = packet(kind, 400)
      assert_equal 'trusted_comment', watch_feedback([frame], [feedback]).first
      assert_equal 'timeout', watch_feedback([frame], [feedback], baseline: feedback).first
    end
  end

  def test_excluded_feedback_does_not_wake
    excluded = packet.merge('excluded_interactions' => [{ 'id' => 400 }])
    assert_equal 'timeout', watch_feedback([frame], [excluded]).first
  end

  def test_closure_stops_feedback_watch
    %w[CLOSED MERGED].each do |state|
      assert_equal 'closed', watch_feedback([frame, frame(state:)], [packet]).first
    end
  end

  def test_transfer_stops_before_ingesting_new_feedback
    transferred = frame.merge(owner: 'm6 · Codex desktop · next')
    packets = [packet, packet('issue_comments', 400)]
    assert_equal 'ownership_transferred', watch_feedback([frame, transferred], packets).first
  end

  def test_head_move_stops_feedback_watch
    assert_equal 'head_moved', watch_feedback([frame, frame(head: MOVED)], [packet]).first
  end

  def test_transfer_during_comment_read_stops_before_work_wake
    github = FeedbackGitHub.new([frame, frame.merge(owner: 'm6 · Codex desktop · next')])
    reader = lambda do
      github.advance
      packet('review_summaries', 400)
    end
    settings = { comments_only: true, owner: OWNER, baseline: packet }
    watcher = Shaka::PrWatch.new(github, head: HEAD, ci_jobs: [], settings:, adapters: { comments: reader })
    assert_equal 'ownership_transferred', watcher.call
  end

  def test_missing_wip_owner_stops_instead_of_claiming_coverage
    github = FeedbackGitHub.new([frame])
    github.define_singleton_method(:api) { |*_args| { 'body' => '', 'head' => { 'sha' => HEAD }, 'state' => 'open' } }
    error = assert_raises(Shaka::Error) { watch_feedback([frame], [packet], github:) }
    assert_includes error.message, 'WIP Details owner'
  end

  def test_feedback_watch_requires_owner_and_saved_baseline
    [{ comments_only: true }, { comments_only: true, owner: OWNER }, { owner: OWNER }].each do |options|
      error = assert_raises(Shaka::Error) do
        Shaka::PrWatch::Command.require_target!(%w[owner/repo 42], options.merge(head: HEAD, ref: HEAD))
      end
      assert_includes error.message, '--comments-only'
    end
  end

  def test_command_passes_feedback_scope_and_owner_without_changing_ci_wait
    options, = Shaka::PrWatch::Command.parse(['--comments-only', '--owner', OWNER])
    seam = Struct.new(:review, :merge).new({ 'ci_review_wait' => 'all' }, {})
    settings = Shaka::PrWatch::Command.watch_settings(options, seam)
    assert_true settings.fetch(:comments_only)
    assert_equal OWNER, settings.fetch(:owner)
    assert_equal 'all', settings.fetch(:ci_review_wait)
  end

  def test_owner_from_a_shell_without_a_utf8_locale_matches_the_published_owner
    options, = Shaka::PrWatch::Command.parse(['--comments-only', '--owner', OWNER.b])
    owner = options.fetch(:owner)
    assert_equal OWNER, owner
    assert_equal 'timeout', watch_feedback([frame], [packet], owner:).first
  end

  def test_owner_that_is_not_utf8_is_refused
    error = assert_raises(Shaka::Error) { Shaka::PrWatch::Command.parse(['--owner', "m5 \xB7 Codex".b]) }
    assert_includes error.message, '--owner'
  end

  private

  def packet(kind = nil, id = nil)
    comments_packet(frame).tap { |result| result[kind] = [{ 'id' => id }] if kind }
  end

  def watch_feedback(frames, packets, baseline: packet, github: FeedbackGitHub.new(frames), owner: OWNER)
    now = 0
    reader = -> { packets.fetch([now, packets.length - 1].min) }
    sleeper = lambda do |seconds|
      now += seconds
      github.advance
    end
    settings = { comments_only: true, owner:, baseline:, interval: 1, settle: 1, timeout: 3 }
    adapters = { clock: -> { now }, sleeper:, comments: reader }
    [Shaka::PrWatch.new(github, head: HEAD, ci_jobs: ['claude-review'], settings:, adapters:).call, now]
  end
end
