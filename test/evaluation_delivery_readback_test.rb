# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_readback'
require_relative 'support/evaluation_delivery_fixture'

class EvaluationDeliveryReadbackTest < Minitest::Test
  include EvaluationDeliveryFixture

  def test_native_review_identity_and_readback_completion_are_retained
    receipt = capture
    row = receipt.fetch('review')
    assert_equal '5566107686', row['fullDatabaseId']
    assert_equal NODE, row['id']
    assert_equal "sha256:#{Digest::SHA256.hexdigest('fixture review')}", row['body_digest']
    assert_equal review, row.except('body_digest')
  end

  def test_query_is_read_only_and_clock_follows_native_completion
    before = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    receipt = capture
    assert_operator receipt['readback_finished_at'], :>, before
    request = JSON.parse(File.read(File.join(@directory, 'request.json')))
    assert_equal ['api', '--hostname', 'github.com', 'graphql', '--input', '-'], request['argv']
    assert_equal({ 'id' => NODE }, request.dig('request', 'variables'))
    assert_includes request.dig('request', 'query'), 'fullDatabaseId'
  end

  def test_later_body_or_timestamp_changes_are_detected
    receipt = capture
    assert reader.unchanged?(receipt)
    { 'body' => 'edited walkthrough', 'updatedAt' => '2026-10-18T00:00:02Z' }.each do |field, value|
      write_review(review.merge(field => value))
      refute reader.unchanged?(receipt), field
    end
  end

  def test_moved_head_or_missing_review_is_not_unchanged
    receipt = capture
    row = review
    row['pullRequest']['headRefOid'] = 'b' * 40
    write_review(row)
    refute reader.unchanged?(receipt)
    write_review(nil)
    refute reader.unchanged?(receipt)
  end

  def test_wrong_native_review_identity_never_produces_a_receipt
    [{ 'id' => 'another-node' }, { 'fullDatabaseId' => '7' }, { 'state' => 'APPROVED' },
     { 'author' => { 'login' => 'another-actor' } }, { 'commit' => { 'oid' => 'b' * 40 } }].each do |change|
      write_review(review.merge(change))
      assert_raises(IOError) { capture }
    end
  end

  def test_wrong_pr_identity_never_produces_a_receipt
    { 'number' => 2, 'state' => 'MERGED', 'headRefOid' => 'b' * 40,
      'repository' => { 'nameWithOwner' => 'other/cell' } }.each do |field, value|
      row = review
      row['pullRequest'][field] = value
      write_review(row)
      assert_raises(IOError) { capture }
    end
  end

  def test_missing_or_invalid_fields_are_not_readback_evidence
    [nil, [], {}, review.merge('body' => nil), review.merge('createdAt' => nil),
     review.merge('submittedAt' => 'not-a-time'), review.merge('updatedAt' => '2026-10-17T00:00:00Z')].each do |row|
      write_review(row)
      assert_raises(IOError) { capture }
    end
  end

  def test_input_refusals_precede_the_native_call
    assert_raises(ArgumentError) { reader(head: 'main') }
    assert_raises(ArgumentError) { reader(seconds: Float::INFINITY) }
    assert_raises(ArgumentError) { reader.read(node_id: NODE, review_id: 0, actor: 'fixture-agent') }
    refute_path_exists File.join(@directory, 'request.json')
  end
end
