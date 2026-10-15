# frozen_string_literal: true

require_relative 'local_review_comment_test'

class LocalReviewBudgetPublicationTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_actual_publication_shows_failed_starts_and_the_execution_bound
    content = { 'rounds' => [round(findings: [NIT.merge('class' => 'defect')])],
                'local_max_rounds' => 3, 'task_budget' => budget(3, 3) }
    body = publish(content).split('<details>').first
    assert_includes body, '3 of 3 review starts'
    assert_includes body, 'Approved continuation'
    assert_includes body, '## Loop bound reached'
    assert_includes body, 'task execution budget (3)'
    assert_includes body, 'Ready task-reassessment prompt'
  end

  def test_remaining_slots_do_not_show_the_bound_warning
    content = { 'rounds' => [round(findings: [NIT.merge('class' => 'defect')])],
                'local_max_rounds' => 3, 'task_budget' => budget(2, 3) }
    body = publish(content)
    assert_includes body, '2 of 3 review starts'
    refute_includes body, 'Loop bound reached'
  end

  def test_several_reviewers_of_one_commit_can_exhaust_the_execution_budget
    defect = NIT.merge('class' => 'defect')
    other = round(reviewer: 'anthropic/claude', report: report(reviewer: 'anthropic/claude'), findings: [defect])
    content = { 'rounds' => [round(findings: [defect]), other],
                'local_max_rounds' => 2, 'task_budget' => budget(2, 2) }
    body = Shaka::LocalReviewLoopComment.new(content, subject: ->(_) { 'Subject' }).render
    assert_includes body, '2 of 2 review starts'
    assert_includes body, 'Loop bound reached'
  end

  def test_malformed_budgets_refuse_publication_before_any_comment_is_written
    [nil, false, {}, 'broken', budget(0, 1)].each do |record|
      github = LocalReviewPublishTest::FakeGitHub.new
      status, error = failed_publication(record, github)
      assert_equal 1, status
      assert_includes error, 'Invalid task review budget'
      assert_empty github.replies
    end
  end

  private

  def failed_publication(record, github)
    Tempfile.create(['budget-', '.json']) do |file|
      file.write(JSON.generate('rounds' => [round], 'task_budget' => record))
      file.close
      _output, error = capture_io do
        @status = Shaka::LocalReview.run(['publish', 'o/r', '7', '--content-file', file.path], github:)
      end
      [@status, error]
    end
  end

  def budget(used, limit) = { 'used' => used, 'limit' => limit, 'reason' => 'Approved continuation' }

  def publish(content)
    github = LocalReviewPublishTest::FakeGitHub.new
    Tempfile.create(['budget-', '.json']) do |file|
      file.write(JSON.generate(content))
      file.close
      capture_io { @status = Shaka::LocalReview.run(['publish', 'o/r', '7', '--content-file', file.path], github:) }
      assert_equal 0, @status
      github.replies.last.last
    end
  end
end
