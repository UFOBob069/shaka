# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/evaluation_budget_fixture'
require_relative '../eval/lib/shaka/evaluation/runner'

class EvaluationRunnerTest < Minitest::Test
  include EvaluationBudgetFixture

  def test_budget_stops_the_next_executor_and_retains_overrun
    calls = 0
    result = runner.run(tasks(3)) do |task, id|
      calls += 1
      record(task, id, 3)
    end
    assert_equal 2, calls
    assert_equal 'partial', result.fetch('status')
    assert_equal '6.0', result.fetch('dollars')
    assert_equal '6.0', budget.snapshot.fetch('monthly_dollars')
    assert_equal 2, saved_records.size
  end

  def test_exact_cap_at_the_end_completes_without_a_release_claim
    result = runner.run(tasks) { |task, id| record(task, id, 5) }
    assert_equal 'complete', result.fetch('status')
    assert_equal 1, result.fetch('completed')
    refute result.key?('clean')
    refute result.key?('quality')
  end

  def test_failed_trials_are_charged_and_never_retried
    result = runner.run(tasks) do |task, id|
      record(task, id, 2).tap { |entry| entry['outcome']['state'] = 'FAIL' }
    end
    assert_equal 'complete', result.fetch('status')
    assert_equal '2.0', budget.snapshot.fetch('monthly_dollars')
  end

  def test_harness_error_is_retained_charged_and_stops_the_batch
    result = runner.run(tasks(2)) do |task, id|
      record(task, id, 1).merge('outcome' => { 'state' => 'HARNESS_ERROR', 'harness_error' => 'Synthetic failure' })
    end
    assert_equal 'harness_error', result.fetch('status')
    assert_equal 1, result.fetch('completed')
    assert_equal '1.0', budget.snapshot.fetch('monthly_dollars')
  end

  def test_unknown_usage_is_saved_and_blocks_later_runs
    result = runner.run(tasks) { |task, id| record(task, id, 'UNKNOWN') }
    assert_equal 'harness_error', result.fetch('status')
    assert_equal 1, saved_records.size
    assert_equal 1, budget.snapshot.fetch('pending')
  end

  def test_later_run_does_not_call_executor_when_cost_is_unaccounted
    runner.run(tasks) { |task, id| record(task, id, 'UNKNOWN') }
    calls = 0
    result = runner.run(tasks) { calls += 1 }
    assert_equal 0, calls
    assert_equal 'unaccounted_trial', result.fetch('reason')
  end

  def test_executor_failure_is_private_and_leaves_an_unsettled_charge
    result = runner.run(tasks) { raise 'private-secret-from-executor' }
    assert_equal 'harness_error', result.fetch('status')
    refute_includes JSON.generate(result), 'private-secret'
    assert_equal 1, budget.snapshot.fetch('pending')
  end

  def test_all_tasks_are_checked_before_any_execution
    invalid = tasks(2)
    invalid.last['tier'] = 4
    calls = 0
    assert_raises(ArgumentError) { runner.run(invalid) { calls += 1 } }
    assert_equal 0, calls
    assert_equal 0, budget.snapshot.fetch('pending')
  end

  def test_tier_three_is_manual_only
    plan = tasks
    plan.first['tier'] = 3
    assert_raises(ArgumentError) { runner.run(plan) { flunk 'must not execute' } }
    account = budget(kind: 'manual', scope: 'delivery', cap: 3)
    result = runner(account).run(plan) { |task, id| record(task, id, 1) }
    assert_equal 'complete', result.fetch('status')
  end

  def test_records_and_ledger_are_private
    runner.run(tasks) { |task, id| record(task, id, 1) }
    paths = Dir.glob(File.join(@directory, '{records/*.json,budget/*}'))
    paths.each { |path| assert_equal 0, File.stat(path).mode & 0o077 }
  end
end
