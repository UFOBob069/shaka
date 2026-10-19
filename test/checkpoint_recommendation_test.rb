# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/checkpoint_recommendation'
require 'shaka/post_implementation/evidence'

class CheckpointRecommendationTest < Minitest::Test
  HEAD = 'a' * 40
  Client = Struct.new(:issue_comments, :viewer_login)

  def checkpoint(recommendation, adequacy: nil)
    marker = "#{Shaka::PostImplementationEvidence.adequacy(adequacy)}\n" if adequacy
    body = "<!-- shaka:reply:post-implementation-aaaaaaa-abc12345 -->\nReport\n\n#{marker}" \
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

  def test_the_verification_verdict_comes_from_the_published_checkpoint
    comments = [checkpoint('Merge', adequacy: 'adequate with accepted gaps')]
    resolved = resolve({ 'checkpoint' => { 'head' => HEAD } }, comments)
    assert_equal 'adequate with accepted gaps', resolved.dig('checkpoint', 'verification_adequacy')
  end

  def test_an_agent_supplied_verification_verdict_is_refused
    content = { 'checkpoint' => { 'head' => HEAD, 'verification_adequacy' => 'adequate' } }
    error = assert_raises(Shaka::Error) { resolve(content, [checkpoint('Merge', adequacy: 'inadequate')]) }
    assert_includes error.message, 'verification_adequacy comes from the published checkpoint'
  end

  def test_content_without_a_checkpoint_is_unchanged
    content = { 'summary' => 'Done.' }
    assert_same content, resolve(content, [])
  end
end
