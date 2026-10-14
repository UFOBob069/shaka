# frozen_string_literal: true

require_relative 'local_review_assessment_test'

class LocalReviewHistoryValidationTest < Minitest::Test
  include SyntheticReviewAssessment

  INVALID_HISTORY = [nil, {}, '', false, 1, [{}], [[nil]]].freeze

  def test_malformed_history_is_rejected_before_any_comment_is_published
    reviewed_finding
    INVALID_HISTORY.each do |history|
      content = with_history(history)
      github = LocalReviewCommitPublishTest::Timeline.new
      assert_raises(Shaka::Error) { Shaka::LocalReviewPublisher.new(content, github, 'o/r').publish }
      assert_empty github.replies
    end
  end

  def test_assessment_reference_lookup_rejects_malformed_history
    reviewed_finding
    ledger.assess!(assessment)
    INVALID_HISTORY.each do |history|
      content = with_history(history)
      judgments = Shaka::LocalReviewAssessments.new(content)
      entry = judgments.entries.first
      assert_raises(Shaka::Error) { judgments.historically_available?(entry) }
    end
  end

  def test_retriage_rejects_malformed_history_without_rewriting_the_ledger
    reviewed_finding
    INVALID_HISTORY.each do |history|
      File.write(@path, JSON.generate(with_history(history)))
      original = File.read(@path)
      assert_raises(Shaka::Error) { record([NIT.merge('note' => 'Changed triage')]) }
      assert_equal original, File.read(@path)
    end
  end

  def test_empty_history_and_empty_snapshots_remain_valid
    reviewed_finding
    [[], [[]]].each do |history|
      content = with_history(history)
      assert Shaka::LocalReviewComment.new(content).render
    end
  end

  private

  def with_history(value)
    saved.tap { |content| content['rounds'].first['earlier_findings'] = value }
  end
end

class LocalReviewActiveActionPresentationTest < Minitest::Test
  include SyntheticReviewAssessment

  def test_active_actions_and_uncertain_attribution_are_visible
    reviewed_finding
    ledger.assess!(assessment(action: { 'taken' => 'reverted', 'attribution' => 'uncertain' }))
    visible = CGI.unescapeHTML(view(EARLIER).split('<details>').first)
    assert_includes visible, 'action: reverted'
    assert_includes visible, 'action attribution: uncertain'
  end

  def test_missing_action_attribution_is_not_invented
    reviewed_finding
    ledger.assess!(assessment(action: { 'taken' => 'not_attempted' }))
    visible = CGI.unescapeHTML(view(EARLIER).split('<details>').first)
    assert_includes visible, 'action: not_attempted'
    refute_includes visible, 'action attribution'
  end
end
