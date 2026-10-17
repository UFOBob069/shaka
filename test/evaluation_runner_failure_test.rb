# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/evaluation_budget_fixture'
require_relative '../eval/lib/shaka/evaluation/runner'

class EvaluationRunnerFailureTest < Minitest::Test
  include EvaluationBudgetFixture

  def test_wrong_trial_binding_stops_without_clearing_the_charge
    result = runner.run(tasks) { |task, _id| record(task, 'wrong-trial', 1) }
    assert_equal 'harness_error', result.fetch('status')
    assert_equal 1, budget.snapshot.fetch('pending')
  end

  def test_wrong_task_binding_does_not_settle_usage
    result = runner.run(tasks) do |task, id|
      record(task.merge('id' => 'another-task'), id, 1)
    end
    assert_equal 'harness_error', result.fetch('status')
    assert_equal 1, budget.snapshot.fetch('pending')
  end

  def test_storage_failure_never_clears_a_charge
    File.write(File.join(@directory, 'records'), 'Synthetic obstruction')
    result = runner.run(tasks) { |task, id| record(task, id, 1) }
    assert_equal 'UNKNOWN', result.fetch('dollars')
    assert_equal 1, budget.snapshot.fetch('pending')
  end

  def test_executor_cannot_mutate_the_expected_task_binding
    result = runner.run(tasks) do |task, id|
      task['id'].replace('changed-task')
      record(task, id, 1)
    end
    assert_equal 'harness_error', result.fetch('status')
    assert_equal 1, budget.snapshot.fetch('pending')
  end

  def test_harness_error_keeps_its_reason_even_when_cost_exceeds_the_cap
    result = runner.run(tasks) do |task, id|
      record(task, id, 6).merge('outcome' => { 'state' => 'HARNESS_ERROR', 'harness_error' => 'Synthetic failure' })
    end
    assert_equal 'harness_error', result.fetch('status')
    assert_equal '6.0', budget.snapshot.fetch('monthly_dollars')
  end

  def test_month_end_does_not_hide_an_overrun_in_the_reservation_month
    @now = Time.utc(2026, 10, 31, 23, 59, 50)
    earlier = budget(kind: 'manual', scope: 'earlier-trials', cap: 200)
    settle(earlier, earlier.reserve, 199)
    result = runner.run(tasks) do |task, id|
      @now += 60
      record(task, id, 2)
    end
    assert_equal 'partial', result.fetch('status')
    assert_equal 'cap_exceeded', result.fetch('reason')
  end

  def test_serialized_record_must_still_satisfy_the_schema
    result = runner.run(tasks) do |task, id|
      record(task, id).merge('score' => Rational(5, 4))
    end
    assert_equal 'harness_error', result.fetch('status')
    assert_empty saved_records
    assert_equal 1, budget.snapshot.fetch('pending')
  end
end
