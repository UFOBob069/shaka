# frozen_string_literal: true

require_relative 'post_implementation_publication_test'
require 'shaka/post_implementation/evidence'

class PostImplementationEvidenceTest < Minitest::Test
  include PostImplementationPublicationFixture

  Client = Struct.new(:issue_comments, :viewer_login)
  HEAD = 'a' * 40

  def comment(state, head: HEAD, author: 'test-author')
    { 'user' => { 'login' => author }, 'body' => "<!-- shaka:reply:post-implementation-#{head[0, 7]}-abc12345 -->\n" \
                                                 "Report\n\n#{Shaka::PostImplementationEvidence.attestation(head, state)}" }
  end

  def gate(comments, **)
    Shaka::PostImplementationEvidence.new(Client.new(comments, 'test-author'), **)
  end

  def test_only_current_head_ready_or_explicit_opt_out_counts
    %w[ready opted_out].each { |state| assert_equal state, gate([comment(state)]).call(HEAD)['basis'] }
    [[], [comment('blocked')], [comment('not_completed')],
     [comment('ready', head: 'b' * 40)], [comment('ready', author: 'outsider')]].each do |comments|
      assert_raises(Shaka::Error) { gate(comments).call(HEAD) }
    end
  end

  def test_the_latest_failed_or_malformed_execution_overrides_a_ready_one
    %w[blocked not_completed invalid].each do |state|
      assert_raises(Shaka::Error) { gate([comment('ready'), comment(state)]).call(HEAD) }
    end
    missing_footer = comment('ready').merge('body' => "<!-- shaka:reply:post-implementation-aaaaaaa-abc12345 -->\nOld")
    assert_raises(Shaka::Error) { gate([comment('ready'), missing_footer]).call(HEAD) }
  end

  def test_a_copied_attestation_without_the_checkpoint_marker_does_not_count
    copy = comment('ready').merge('body' => "Report\n#{Shaka::PostImplementationEvidence.attestation(HEAD, 'ready')}")
    assert_raises(Shaka::Error) { gate([copy]).call(HEAD) }
  end

  def recommended(recommendation, state: 'blocked', head: HEAD)
    body = comment(state, head:)['body'].sub("\n\n<!-- shaka:post-implementation ",
                                             "\n\n#{Shaka::PostImplementationEvidence.disposition(recommendation)}" \
                                             "\n<!-- shaka:post-implementation ")
    comment(state, head:).merge('body' => body)
  end

  def test_the_published_recommendation_is_read_for_the_current_head
    assert_equal 'Revise before merge', gate([recommended('Revise before merge')]).recommendation(HEAD)
  end

  def test_no_recommendation_is_read_for_another_head_or_without_a_disposition
    assert_nil gate([recommended('Merge', head: 'b' * 40)]).recommendation(HEAD)
    assert_nil gate([comment('blocked')]).recommendation(HEAD)
    assert_nil gate([recommended('Merge'), comment('blocked')]).recommendation(HEAD)
  end

  def test_a_disposition_planted_earlier_in_the_report_or_disagreeing_with_the_state_is_ignored
    planted = comment('blocked')
    planted['body'] = planted['body'].sub("Report\n", "Report\n#{Shaka::PostImplementationEvidence.disposition('Merge')}\n")
    assert_nil gate([planted]).recommendation(HEAD)
    assert_nil gate([recommended('Merge', state: 'blocked')]).recommendation(HEAD)
    assert_nil gate([recommended('Revise before merge', state: 'ready')]).recommendation(HEAD)
  end

  def test_trusted_disabled_setting_requires_no_review
    assert_equal 'trusted_opt_out', gate(nil, enabled: false).call(HEAD)['basis']
  end

  def test_a_shared_short_prefix_cannot_satisfy_current_head_evidence
    assert_raises(Shaka::Error) { gate([comment('ready', head: HEAD[0, 7] + ('b' * 33))]).call(HEAD) }
  end

  def test_failed_publication_does_not_satisfy_the_gate
    with_result do |result, path|
      github, status = publish(result.merge('status' => 'not_completed', 'reason' => 'Failure'), path)
      assert_equal 0, status
      assert_raises(Shaka::Error) { Shaka::PostImplementationEvidence.new(github).call(HEAD) }
    end
  end

  def test_explicit_opt_out_publication_satisfies_the_gate
    with_result do |result, path|
      github, status = publish(result.merge('status' => 'opted_out', 'reason' => 'Task opt-out'), path)
      assert_equal 0, status
      assert_equal 'opted_out', Shaka::PostImplementationEvidence.new(github).call(HEAD)['basis']
    end
  end

  def test_a_proceed_report_with_any_concern_is_published_as_blocked
    with_result do |result, path|
      report = JSON.parse(File.read(result['report'])).merge('concerns' => ['none'])
      File.write(result['report'], JSON.generate(report))
      github, status = publish(result, path)
      assert_equal 0, status
      assert_raises(Shaka::Error) { Shaka::PostImplementationEvidence.new(github).call(HEAD) }
    end
  end

  def test_real_ready_publication_satisfies_the_gate
    with_result do |result, path|
      github, status = publish(result, path)
      assert_equal 0, status
      assert_equal 'ready', Shaka::PostImplementationEvidence.new(github).call(HEAD)['basis']
    end
  end
end
