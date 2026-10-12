# frozen_string_literal: true

require_relative 'handoff_helper'
require 'shaka/github/squash_comment'
require 'shaka/publication/squash_message'

# An Ask handoff stops for a GitHub merge click, so the squash commit message has to be on the PR first.
class HandoffSquashMessageTest < Minitest::Test
  include HandoffHarness

  # Renders the comment exactly as `squash-message` posts it.
  class Poster
    include Shaka::SquashComment

    def render(head)
      squash_comment_body(head, Shaka::SquashMessage.new({ 'title' => 'Fix', 'body' => 'Why.' }, number: 42))
    end
  end

  def squash_comment(head, id: 1, author: 'shaka-agent')
    { 'id' => id, 'body' => Poster.new.render(head), 'user' => { 'login' => author } }
  end

  def awaiting_merge(**pull) = handoff(labels: ['awaiting-merge-approval'], **pull)

  def owed?(result, text) = result.fetch('owed').any? { |item| item.include?(text) }

  def test_merge_approval_without_a_squash_message_is_owed
    result = awaiting_merge

    assert owed?(result, "squash commit message for #{HEAD}")
    assert_includes result['status'], 'no squash message'
  end

  def test_a_squash_message_for_the_live_head_settles_it
    result = awaiting_merge(comments: [squash_comment(HEAD)])

    assert_empty result['owed']
    assert_includes result['status'], "squash message #{HEAD[0, 7]}"
  end

  def test_a_squash_message_for_an_older_head_is_owed
    assert owed?(awaiting_merge(comments: [squash_comment(OLD)]), "post one for #{HEAD}")
  end

  # A fork author can mint a commit sharing the seven characters the comment displays.
  def test_a_squash_message_for_a_head_sharing_only_its_prefix_is_owed
    twin = HEAD[0, 7] + ('b' * 33)

    assert owed?(awaiting_merge(comments: [squash_comment(twin)]), "post one for #{HEAD}")
  end

  def test_the_latest_squash_message_wins
    comments = [squash_comment(HEAD, id: 1), squash_comment(OLD, id: 2)]

    assert owed?(awaiting_merge(comments:), "post one for #{HEAD}")
  end

  def test_a_copied_squash_message_from_another_account_does_not_count
    result = awaiting_merge(comments: [squash_comment(HEAD, author: 'outsider')])

    assert owed?(result, "squash commit message for #{HEAD}")
  end

  def test_a_pr_not_awaiting_merge_reads_no_comments
    assert_empty handoff(comments: nil)['owed']
  end

  def test_final_handoff_owes_both_checkpoint_and_message_until_they_exist
    result = awaiting_merge(post_implementation: {})
    assert owed?(result, 'Checkpoint')
    assert owed?(result, 'squash commit message')
    assert_equal Shaka::Handoff::OWED_EXIT, Shaka::Handoff.exit_status(result)

    checkpoint = { 'user' => { 'login' => 'shaka-agent' },
                   'body' => "<!-- shaka:reply:post-implementation-aaaaaaa-abc12345 -->\nReport\n\n" \
                             "#{Shaka::PostImplementationEvidence.attestation(HEAD, 'ready')}" }
    result = awaiting_merge(post_implementation: {}, comments: [checkpoint, squash_comment(HEAD)])
    assert_empty result['owed']
  end

  def test_in_progress_handoff_does_not_require_an_early_checkpoint
    assert_empty handoff(post_implementation: {}, comments: nil)['owed']
  end
end

class HandoffEvaluationMessageTest < Minitest::Test
  include HandoffHarness

  def checkpoint(state: 'ready', head: HEAD, message_head: HEAD, id: 2, author: 'shaka-agent')
    message = Shaka::SquashMessage.new({ 'title' => 'Fix', 'body' => 'Why.' }, number: 42)
    { 'id' => id, 'user' => { 'login' => author },
      'body' => "<!-- shaka:reply:post-implementation-#{head[0, 7]}-abc12345 -->\nReport\n\n" \
                "#{Shaka::SquashComment.body(message_head, message)}\n" \
                "#{Shaka::PostImplementationEvidence.attestation(head, state)}" }
  end

  def awaiting(comments) = handoff(labels: ['awaiting-merge-approval'], comments:)

  def test_ready_checkpoint_message_settles_ask_handoff
    assert_empty awaiting([checkpoint])['owed']
  end

  def test_mismatched_head_blocked_or_foreign_checkpoint_cannot_settle_it
    [checkpoint(message_head: OLD), checkpoint(state: 'blocked'), checkpoint(author: 'outsider')].each do |comment|
      assert(awaiting([comment])['owed'].any? { |item| item.include?('squash commit message') })
    end
  end

  def test_newer_blocked_checkpoint_invalidates_earlier_merge_text
    assert_predicate(awaiting([checkpoint(id: 1), checkpoint(state: 'blocked')])['owed'], :any?)
  end

  def test_opted_out_handoff_names_the_standalone_message_remedy
    result = awaiting([checkpoint(state: 'opted_out')])
    assert_includes result['owed'].join, '`squash-message` for opt-out'
  end

  def test_republished_opt_out_keeps_the_existing_standalone_message
    body = HandoffSquashMessageTest::Poster.new.render(HEAD)
    standalone = { 'id' => 1, 'body' => body, 'user' => { 'login' => 'shaka-agent' } }
    assert_empty awaiting([standalone, checkpoint(state: 'opted_out')])['owed']
  end

  def test_archived_checkpoint_message_does_not_count
    archived = checkpoint
    archived['body'] = archived['body'].sub('Report', 'Superseded — read the current checkpoint: URL')
    archived['body'] += "\n</details>"
    assert_predicate(awaiting([archived])['owed'], :any?)
  end
end
