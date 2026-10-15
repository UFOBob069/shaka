# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/checkpoint_recommendation'
require 'shaka/post_implementation/evidence'

class CheckpointRecommendationTest < Minitest::Test
  HEAD = 'a' * 40
  Client = Struct.new(:issue_comments, :viewer_login)

  def checkpoint(recommendation)
    body = "<!-- shaka:reply:post-implementation-aaaaaaa-abc12345 -->\nReport\n\n" \
           "#{Shaka::PostImplementationEvidence.disposition(recommendation)}\n" \
           "#{Shaka::PostImplementationEvidence.attestation(HEAD, recommendation == 'Merge' ? 'ready' : 'blocked')}"
    { 'user' => { 'login' => 'agent' }, 'body' => body }
  end

  def resolve(content, comments)
    Shaka::CheckpointRecommendation.resolve(content, Client.new(comments, 'agent'))
  end

  def test_the_heading_comes_from_the_published_checkpoint
    resolved = resolve({ 'checkpoint' => { 'head' => HEAD, 'next_action' => 'Merge it.' } }, [checkpoint('Merge')])
    assert_equal 'Merge', resolved.dig('checkpoint', 'recommendation')
  end

  def test_no_published_disposition_leaves_no_recommendation
    resolved = resolve({ 'checkpoint' => { 'head' => HEAD, 'next_action' => 'Run the checkpoint.' } }, [])
    refute resolved['checkpoint'].key?('recommendation')
  end

  def test_an_agent_supplied_recommendation_is_refused
    content = { 'checkpoint' => { 'head' => HEAD, 'next_action' => 'Merge it.', 'recommendation' => 'Merge' } }
    error = assert_raises(Shaka::Error) { resolve(content, [checkpoint('Revise before merge')]) }
    assert_includes error.message, 'published checkpoint'
  end

  def test_content_without_a_checkpoint_is_unchanged
    content = { 'summary' => 'Done.' }
    assert_same content, resolve(content, [])
  end
end
