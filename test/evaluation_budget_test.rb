# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/evaluation_budget_fixture'
require_relative '../eval/lib/shaka/evaluation/budget'

class EvaluationBudgetTest < Minitest::Test
  include EvaluationBudgetFixture

  def test_explicit_limits_and_lower_requested_caps
    assert_raises(ArgumentError) { Shaka::Evaluation::Budget.new(directory: @directory, kind: 'nightly') }
    assert_equal '2.0', budget(cap: 2).snapshot.fetch('cap')
    assert_raises(ArgumentError) { budget(cap: 6) }
    assert_raises(ArgumentError) { budget(kind: 'manual', scope: 'manual-run') }
  end

  def test_charge_persists_and_is_not_double_counted
    account = budget
    id = account.reserve
    settle(account, id, 3)
    assert_equal '3.0', budget.snapshot.fetch('monthly_dollars')
    assert_raises(Shaka::Evaluation::BudgetError) { settle(account, id, 3) }
    assert_equal '3.0', budget.snapshot.fetch('monthly_dollars')
  end

  def test_night_limit_stops_launches_and_new_night_preserves_month_total
    account = budget
    settle(account, account.reserve, 5)
    error = assert_raises(Shaka::Evaluation::Budget::Stopped) { budget.reserve }
    assert_equal 'scope_cap', error.message
    @now += 86_400
    id = budget.reserve
    settle(budget, id, 1)
    assert_equal '6.0', budget.snapshot.fetch('monthly_dollars')
  end

  def test_monthly_limit_is_shared_by_nightly_pr_and_manual_calls
    @limits['monthly'] = 4
    account = budget
    settle(account, account.reserve, 2)
    account = budget(kind: 'manual', scope: 'delivery', cap: 2)
    settle(account, account.reserve, 2)
    error = assert_raises(Shaka::Evaluation::Budget::Stopped) { budget(kind: 'pr', scope: '578').reserve }
    assert_equal 'monthly_cap', error.message
  end

  def test_pr_cap_persists_across_nights_and_calendar_months
    account = budget(kind: 'pr', scope: '578')
    settle(account, account.reserve, 15)
    @now = Time.utc(2026, 11, 1)
    assert_equal '0.0', budget.snapshot.fetch('monthly_dollars')
    error = assert_raises(Shaka::Evaluation::Budget::Stopped) { budget(kind: 'pr', scope: '578').reserve }
    assert_equal 'scope_cap', error.message
  end

  def test_unsettled_call_blocks_other_processes_and_period_rollover
    account = budget
    id = account.reserve
    @now = Time.utc(2026, 11, 1)
    error = assert_raises(Shaka::Evaluation::Budget::Stopped) { budget.reserve }
    assert_equal 'unaccounted_trial', error.message
    settle(account, id, 2)
    assert budget.reserve
  end

  def test_decimal_sums_do_not_allow_an_extra_call
    @limits['nightly'] = 0.3
    account = budget
    [0.1, 0.2].each { |cost| settle(account, account.reserve, cost) }
    assert_equal '0.3', account.snapshot.fetch('scope_dollars')
    assert_raises(Shaka::Evaluation::Budget::Stopped) { account.reserve }
  end

  def test_invalid_cost_keeps_the_reservation_unaccounted
    account = budget
    id = account.reserve
    ['UNKNOWN', -1, Float::NAN, Float::INFINITY].each do |amount|
      assert_raises(Shaka::Evaluation::BudgetError) { settle(account, id, amount) }
    end
    assert_equal 1, account.snapshot.fetch('pending')
    assert_raises(Shaka::Evaluation::Budget::Stopped) { account.reserve }
  end

  def test_unknown_or_foreign_settlement_cannot_clear_a_reservation
    account = budget
    id = account.reserve
    assert_raises(Shaka::Evaluation::BudgetError) { settle(budget(kind: 'pr', scope: 'other'), id, 1) }
    assert_raises(Shaka::Evaluation::BudgetError) { settle(account, 'missing', 1) }
    assert_equal 1, account.snapshot.fetch('pending')
  end

  def test_corrupt_or_truncated_ledger_stops_spending
    account = budget
    account.reserve
    File.open(File.join(@directory, 'budget/budget.jsonl'), 'a') { |file| file.write('{"private-value":') }
    error = assert_raises(Shaka::Evaluation::BudgetError) { account.reserve }
    refute_includes error.message, 'private-value'
  end

  def test_invalid_caps_and_scope_are_rejected_before_ledger_creation
    [-1, 'UNKNOWN', Float::INFINITY].each do |value|
      assert_raises(ArgumentError) { budget(limits: @limits.merge('monthly' => value)) }
    end
    assert_raises(ArgumentError) { budget(kind: 'pr') }
    refute_path_exists File.join(@directory, 'budget')
  end
end
