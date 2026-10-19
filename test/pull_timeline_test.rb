# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/github/pull_timeline'
require 'shaka/publication/timing_stretches'

# The timeline comes from one paged GraphQL read, and a failed read becomes a reason rather than an error.
class PullTimelineTest < Minitest::Test
  # Answers each page of the timeline query from a list.
  class FakeGitHub
    attr_reader :cursors, :repository, :number

    def initialize(pages)
      @repository = 'owner/repo'
      @number = 7
      @pages = pages
      @cursors = []
    end

    def graphql(_query, variables)
      @cursors << variables[:cursor]
      page = @pages.shift or raise Shaka::Error, 'GraphQL failed or returned missing data.'
      { 'repository' => { 'pullRequest' => page } }
    end
  end

  def page(nodes, next_cursor: nil)
    { 'state' => 'MERGED', 'createdAt' => '2026-10-18T08:00:00Z', 'mergedAt' => '2026-10-18T09:00:00Z',
      'closedAt' => '2026-10-18T09:00:00Z',
      'commits' => { 'nodes' => [{ 'commit' => { 'committedDate' => '2026-10-18T07:30:00Z' } }] },
      'timelineItems' => { 'pageInfo' => { 'hasNextPage' => !next_cursor.nil?, 'endCursor' => next_cursor },
                           'nodes' => nodes } }
  end

  def event(type, name, minute)
    { '__typename' => type, 'createdAt' => "2026-10-18T08:#{minute}:00Z", 'label' => { 'name' => name } }
  end

  def read(pages) = Shaka::PullTimeline.new(FakeGitHub.new(pages)).call

  def test_reads_every_page_and_keeps_only_attention_labels
    github = FakeGitHub.new([page([event('LabeledEvent', 'documentation', '01'),
                                   event('LabeledEvent', 'awaiting-answer', '10')], next_cursor: 'c1'),
                             page([event('UnlabeledEvent', 'Awaiting-Answer', '40')])])
    timeline = Shaka::PullTimeline.new(github).call
    assert_equal [nil, 'c1'], github.cursors
    labels = timeline['labels'].map { |label| label.values_at('name', 'added') }
    assert_equal [['awaiting-answer', true], ['awaiting-answer', false]], labels
  end

  def test_events_in_the_same_second_keep_github_order
    swap = [event('UnlabeledEvent', 'awaiting-answer', '10'), event('LabeledEvent', 'awaiting-merge-approval', '10'),
            event('UnlabeledEvent', 'awaiting-resume', '10'), event('LabeledEvent', 'awaiting-resume', '10')]
    names = read([page(swap)])['labels'].map { |label| label.values_at('name', 'added') }
    assert_equal [['awaiting-answer', false], ['awaiting-merge-approval', true],
                  ['awaiting-resume', false], ['awaiting-resume', true]], names
  end

  def test_reports_the_first_commit_and_the_merge
    timeline = read([page([])])
    assert_equal [Time.utc(2026, 10, 18, 7, 30), Time.utc(2026, 10, 18, 9)],
                 timeline.values_at('first_commit', 'merged')
  end

  def test_a_reopened_pull_request_is_not_read_as_closed
    reopened = page([]).merge('state' => 'OPEN', 'mergedAt' => nil)
    assert_nil read([reopened])['closed']
  end

  def test_publishing_decisions_starts_or_ends_the_answer_wait_now
    now = Time.utc(2026, 10, 18, 10)
    timeline = { 'labels' => [] }
    started = Shaka::PullTimeline.with_decisions(timeline, { 'decisions' => ['Which base?'] }, now)['labels']
    ended = Shaka::PullTimeline.with_decisions(timeline, { 'decisions' => [] }, now)['labels']
    assert_equal(['awaiting-answer', true, now], started.last.values_at('name', 'added', 'at'))
    assert_equal([['awaiting-answer', false]], ended.map { |event| event.values_at('name', 'added') })
    assert_same timeline, Shaka::PullTimeline.with_decisions(timeline, {}, now)
  end

  def test_an_answer_wait_ends_the_resume_wait_it_replaces
    opened = Time.utc(2026, 10, 18, 8)
    resume = { 'name' => 'awaiting-resume', 'added' => true, 'at' => opened + 600 }
    timeline = { 'opened' => opened, 'labels' => [resume] }
    projected = Shaka::PullTimeline.with_decisions(timeline, { 'decisions' => ['Which base?'] }, opened + 3600)
    names = Shaka::TimingStretches.new(projected, opened + 3600).rows.map { |row| row[:name] }
    assert_equal ['Between checkpoints', 'Waiting on a person: resume', 'Waiting on a person: answer'], names
  end

  def test_a_failed_read_is_reported_as_unavailable
    assert_equal({ 'unavailable' => 'GraphQL failed or returned missing data.' }, read([]))
  end

  def test_a_timeline_longer_than_the_page_limit_is_unavailable_rather_than_cut_short
    pages = Array.new(Shaka::PullTimeline::MAX_PAGES) { |index| page([], next_cursor: "c#{index}") }
    assert_match(/more than/, read(pages)['unavailable'])
  end
end
