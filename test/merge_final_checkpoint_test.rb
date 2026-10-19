# frozen_string_literal: true

require_relative 'merge_test'
require 'shaka/post_implementation/evidence'
require 'shaka/publication/squash_message'

class MergeFinalCheckpointTest < Minitest::Test
  include MergeFixtures

  def product_comment(state, adequacy: nil)
    marker = "#{Shaka::PostImplementationEvidence.adequacy(adequacy)}\n" if adequacy
    { 'user' => { 'login' => 'shaka-agent' },
      'body' => "<!-- shaka:reply:post-implementation-aaaaaaa-abc12345 -->\nReport\n\n" \
                "#{marker}#{Shaka::PostImplementationEvidence.attestation(HEAD, state)}" }
  end

  def merge_with_adequacy(adequacy, confirmed: nil)
    @client.comments << product_comment('ready', adequacy:)
    checkpoint = Shaka::PostImplementationEvidence.new(@client)
    message = Shaka::SquashMessage.new({ 'title' => 'Fix', 'body' => 'Reason.' }, number: 42)
    Shaka::Merge.new(@client, review: { checkpoint:, adequacy_confirmed_head: confirmed })
                .call(head: HEAD, base: BASE, walkthrough: 17, squash_message: message)
  end

  def test_inadequate_verification_stops_an_unconfirmed_agent_merge
    error = assert_raises(Shaka::Error) { merge_with_adequacy('inadequate') }
    assert_includes error.message, 'verification inadequate'
    assert_empty @client.mutations
  end

  def test_a_confirmation_for_another_head_does_not_excuse_inadequate_verification
    assert_raises(Shaka::Error) { merge_with_adequacy('inadequate', confirmed: 'c' * 40) }
    assert_empty @client.mutations
  end

  def test_the_user_approving_this_head_lets_inadequate_verification_merge
    assert_equal 'MERGED', merge_with_adequacy('inadequate', confirmed: HEAD)['state']
  end

  def test_only_inadequate_verification_stops_the_merge
    assert_equal 'MERGED', merge_with_adequacy('cannot judge')['state']
  end

  def publish_during_last_snapshot(comment)
    snapshot = @client.method(:snapshot)
    reads = 0
    @client.define_singleton_method(:snapshot) do
      result = snapshot.call
      comments << comment if (reads += 1) == 2
      result
    end
  end

  def test_a_blocking_checkpoint_arriving_during_the_last_native_read_prevents_submission
    @client.comments << product_comment('ready')
    checkpoint = Shaka::PostImplementationEvidence.new(@client)
    assert_equal 'ready', checkpoint.call(HEAD)['basis']
    publish_during_last_snapshot(product_comment('blocked'))
    @merge = Shaka::Merge.new(@client, review: { checkpoint: })

    assert_blocked(/Checkpoint is missing, stale, or blocked/)
  end

  def test_ready_checkpoint_and_supplied_message_allow_normal_merge
    @client.comments << product_comment('ready')
    checkpoint = Shaka::PostImplementationEvidence.new(@client)
    message = Shaka::SquashMessage.new({ 'title' => 'Fix', 'body' => 'Reason.' }, number: 42)
    merge = Shaka::Merge.new(@client, review: { checkpoint: })

    result = merge.call(head: HEAD, base: BASE, walkthrough: 17, squash_message: message)
    assert_equal 'MERGED', result['state']
    assert_equal 'Reason.', @client.mutations.first.last['body']
  end
end
