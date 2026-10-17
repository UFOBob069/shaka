# frozen_string_literal: true

require_relative 'handoff_helper'

class HandoffThreadsTest < Minitest::Test
  include HandoffHarness

  def test_an_answered_open_thread_is_not_owed
    result = handoff(threads: [thread('T1', replies: ['shaka-agent'])])

    assert_empty result['owed']
    assert_empty result['notes']
  end

  def test_an_unanswered_open_thread_is_owed
    result = handoff(threads: [thread('T1', replies: ['someone-else']), thread('T2', replies: ['shaka-agent'])])

    assert_includes result['status'], '1 unanswered thread'
    assert_equal ['Reply on review threads this account never answered: T1.'], result['owed']
  end

  def test_an_open_thread_this_account_opened_is_not_owed
    open_thread = thread('T1')
    open_thread['comments']['nodes'].first['author']['login'] = 'shaka-agent'

    assert_empty handoff(threads: [open_thread])['owed']
  end

  def test_an_app_account_matches_only_its_own_bot_comments
    answered = thread('T1', replies: ['shaka-agent[bot]'])
    namesake = thread('T2', replies: ['shaka-agent'])
    result = handoff(viewer: 'shaka-agent[bot]', threads: [answered, namesake])

    assert_equal ['Reply on review threads this account never answered: T2.'], result['owed']
  end

  def test_a_resolved_thread_without_a_reply_is_not_owed
    assert_empty handoff(threads: [thread('T1', resolved: true)])['owed']
  end

  def test_a_replied_thread_left_open_is_counted_only_for_merge_approval
    threads = [thread('T1', replies: ['shaka-agent']), thread('T2', replies: ['shaka-agent'])]
    labels = ['awaiting-merge-approval']

    assert_empty handoff(threads:)['notes']
    result = handoff(threads:, labels:)

    assert_includes result['notes'], '2 answered review threads still open; confirm each is meant to stay open.'
    refute(result['owed'].any? { |item| item.include?('review threads') })
  end

  def test_an_unreadable_thread_list_leaves_a_note_and_the_rest_of_the_report
    result = handoff(threads: :unreadable)

    assert_empty result['owed']
    assert_includes result['notes'], 'Review threads are unread: GraphQL failed or returned missing data.'
    assert_includes result['status'], "walkthrough #{HEAD[0, 7]} · WIP #{HEAD[0, 7]}"
  end

  def test_a_thread_whose_reply_may_be_past_the_first_page_is_noted_not_owed
    long_thread = thread('T1', replies: ['someone-else'])
    long_thread['comments']['pageInfo']['hasNextPage'] = true
    result = handoff(threads: [long_thread])

    assert_empty result['owed']
    assert_includes result['notes'], 'Check by hand for a reply past 100 comments on T1.'
  end
end
