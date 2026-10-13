# frozen_string_literal: true

require_relative 'local_review_test'
require 'shaka/local_review'

module LocalReviewBudgetSteps
  COMMAND = LocalReviewCodexTest::COMMAND

  include LocalReviewLoopSteps
  include LocalReviewFixture

  def teardown
    super
    Array(@results).each { |result| cleanup_artifacts(result) }
  end

  private

  def stored = JSON.parse(File.read(@ledger))

  def next_head(index)
    commit!(@root, "change #{index}", "change #{index}")
    git!(@root, 'rev-parse', 'HEAD').strip
  end

  def advance(head, count, offset: 0, **)
    count.times do |index|
      loop_round(head, findings: 0, **)
      head = next_head(index + offset)
    end
    head
  end

  def assert_budget(used, limit)
    assert_equal used, stored.dig('task_budget', 'used')
    assert_equal limit, stored.dig('task_budget', 'limit')
    assert_equal limit, stored.fetch('local_max_rounds')
  end

  def refused_options(head, options)
    output, _error, status = run_review(@root, @base, head, @bin, options)
    refute_predicate status, :success?, output
    refute_path_exists @ledger
  end

  def concurrent_start(ledger, head, index)
    Thread.new do
      ledger.start!(base: @base, head:, reviewer: "reviewer-#{index}", budget: { limit: 1, reason: 'One start' })
      :started
    rescue Shaka::LocalReviewLedger::RoundCap
      :blocked
    end
  end
end

class LocalReviewBudgetTest < Minitest::Test
  include LocalReviewBudgetSteps

  def test_budget_extends_five_reviews_without_resetting_history_or_adding_overlapping_limits
    in_loop do |head|
      head = advance(head, 5)
      prior = stored.fetch('rounds')
      head = advance(head, 2, offset: 5, max_review_executions: 15, budget_reason: 'Fifteen total authorized')
      assert_equal prior, stored.fetch('rounds').first(5)
      assert_budget(7, 15)
      assert_includes File.read(@trace), 'PRIOR ROUNDS'
      assert_exhausted(advance(head, 8, offset: 7))
    end
  end

  def test_budget_persists_and_refuses_a_second_reviewer_of_the_same_head
    in_loop do |head|
      loop_round(head, findings: 0, max_review_executions: 1, budget_reason: 'One review')
      FileUtils.rm(@trace)
      output, _error, status = run_review(@root, @base, head, @bin, ledger: @ledger, reviewer: 'anthropic/claude')

      refute_predicate status, :success?
      assert_equal 'round_cap', JSON.parse(output).fetch('failure_stage')
      assert_includes JSON.parse(output).fetch('reason'), 'Task review execution budget (1) reached'
      refute_path_exists @trace
      assert_equal 1, stored.dig('task_budget', 'used')
    end
  end

  def test_failed_launch_consumes_a_slot_and_retry_does_not_reset_it
    in_loop do |head|
      write_executable(@bin, 'codex', "#!/bin/sh\nexit 42\n")
      options = { ledger: @ledger, max_review_executions: 1, budget_reason: 'One launch' }
      first = JSON.parse(run_review(@root, @base, head, @bin, options).first)
      second = JSON.parse(run_review(@root, @base, head, @bin, options).first)

      assert first.fetch('attempted')
      refute second.fetch('attempted')
      assert_equal 'round_cap', second.fetch('failure_stage')
      assert_failed_budget
    end
  end

  private

  def assert_exhausted(head)
    FileUtils.rm(@trace)
    assert_refused(head, 'Task review execution budget (15) reached')
    refute_path_exists @trace
    assert_budget(15, 15)
  end

  def assert_failed_budget
    assert_equal 1, stored.dig('task_budget', 'used')
    assert_empty stored.fetch('rounds')
  end
end

class LocalReviewBudgetValidationTest < Minitest::Test
  include LocalReviewBudgetSteps

  def test_budget_requires_a_positive_total_a_reason_and_a_ledger
    in_loop do |head|
      invalid = [{ max_review_executions: 0, budget_reason: 'Reason' },
                 { max_review_executions: '1.5', budget_reason: 'Reason' },
                 { max_review_executions: 2 }, { budget_reason: 'Reason' },
                 { max_review_executions: 2, budget_reason: ' ' }]
      invalid.each { |options| refused_options(head, options.merge(ledger: @ledger)) }
      refused_options(head, max_review_executions: 2, budget_reason: 'Reason')
    end
  end

  def test_concurrent_starts_share_one_budget_and_cannot_overbook
    in_loop do |head|
      ledgers = Array.new(2) { Shaka::LocalReviewLedger.new(@ledger) }
      results = ledgers.each_with_index.map { |ledger, index| concurrent_start(ledger, head, index) }.map(&:value)
      assert_equal %i[blocked started], results.sort
      assert_equal 1, stored.dig('task_budget', 'used')
    ensure
      ledgers&.each(&:finish!)
    end
  end

  def test_an_explicit_larger_total_preserves_spent_slots_and_malformed_history_is_refused
    in_loop do |head|
      loop_round(head, findings: 0, max_review_executions: 1, budget_reason: 'Initial limit')
      later = next_head(1)
      loop_round(later, findings: 0, max_review_executions: 2, budget_reason: 'One more approved')
      assert_equal 2, stored.dig('task_budget', 'used')
      data = stored
      data['task_budget']['used'] = 0
      File.write(@ledger, JSON.generate(data))
      assert_refused(next_head(2), 'Invalid task review budget')
    end
  end

  def test_a_failed_start_cannot_transfer_its_budget_to_another_base
    in_loop do |head|
      write_executable(@bin, 'codex', "#!/bin/sh\nexit 42\n")
      run_review(@root, @base, head, @bin, ledger: @ledger, max_review_executions: 2, budget_reason: 'Two starts')
      original = File.read(@ledger)
      result = JSON.parse(run_review(@root, head, head, @bin, ledger: @ledger).first)

      refute result.fetch('attempted')
      assert_includes result.fetch('reason'), 'another base'
      assert_equal original, File.read(@ledger)
    end
  end
end

class LocalReviewBudgetGuardTest < Minitest::Test
  include LocalReviewBudgetSteps

  def test_invalid_history_does_not_consume_or_install_a_budget
    in_loop do |head|
      loop_round(head, findings: 0)
      original = File.read(@ledger)
      git!(@root, 'checkout', '-B', 'unrelated', @base)
      unrelated = next_head('unrelated')
      result = budget_attempt(unrelated)
      refute result.fetch('attempted')
      assert_equal original, File.read(@ledger)
    end
  end

  def test_initial_selection_waits_for_legacy_reviews_already_running
    in_loop do |head|
      legacy = Shaka::LocalReviewLedger.new(@ledger)
      legacy.start!(base: @base, head:, reviewer: 'legacy')
      original = File.read(@ledger)
      error = refused_adoption(head)
      assert_includes error.message, 'Wait for legacy'
      assert_equal original, File.read(@ledger)
    ensure
      legacy&.finish!
    end
  end

  def test_first_total_below_completed_history_reports_consumed_starts
    in_loop do |head|
      head = advance(head, 5)
      result = budget_attempt(head)
      assert_includes result.fetch('reason'), 'cannot be lower than its consumed starts'
    end
  end

  private

  def budget_attempt(head)
    options = { ledger: @ledger, max_review_executions: 3, budget_reason: 'Three total' }
    JSON.parse(run_review(@root, @base, head, @bin, options).first)
  end

  def refused_adoption(head)
    assert_raises(Shaka::Error) do
      Shaka::LocalReviewLedger.new(@ledger).start!(base: @base, head:, reviewer: 'new',
                                                   budget: { limit: 2, reason: 'Two starts' })
    end
  end
end

class LocalReviewBudgetMalformedTest < Minitest::Test
  include LocalReviewBudgetSteps

  def test_present_malformed_budgets_cannot_be_replaced_by_a_new_selection
    in_loop do |head|
      loop_round(head, findings: 0)
      later = next_head(1)
      data = stored
      [nil, false, {}, 'broken'].each { |record| assert_malformed_budget(record, later, data) }
    end
  end

  private

  def assert_malformed_budget(record, head, data)
    File.write(@ledger, JSON.generate(data.merge('task_budget' => record)))
    original = File.read(@ledger)
    options = { ledger: @ledger, max_review_executions: 3, budget_reason: 'Three total' }
    result = JSON.parse(run_review(@root, @base, head, @bin, options).first)
    refute result.fetch('attempted')
    assert_includes result.fetch('reason'), 'Invalid task review budget'
    assert_equal original, File.read(@ledger)
  end
end
