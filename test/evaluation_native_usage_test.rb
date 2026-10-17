# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../eval/lib/shaka/evaluation/runner'
require_relative 'support/evaluation_budget_fixture'
require_relative 'support/evaluation_native_fixture'
require_relative '../eval/lib/shaka/evaluation/native_usage'

class EvaluationNativeUsageTest < Minitest::Test
  include EvaluationBudgetFixture
  include EvaluationNativeFixture

  def test_native_session_settles_runner_at_cache_neutral_cost
    setup_native_reader
    account = budget
    result = native_run(codex_rows, account)

    assert_equal 'complete', result['status']
    assert_in_delta 0.21, result['dollars'].to_f, 0.000002
    assert_in_delta 0.21, account.snapshot['monthly_dollars'].to_f, 0.000002
  end

  def test_unknown_native_usage_leaves_the_account_unresolved
    setup_native_reader
    rows = codex_rows
    rows.last['payload']['usage'].delete('output_tokens')
    result = native_run(rows, budget)
    assert_equal 'harness_error', result['status']
    assert_raises(Shaka::Evaluation::Budget::Stopped) { budget.reserve }
  end

  private

  def native_run(rows, account)
    runner(account).run(tasks) { |task, id| record(task, id).merge('usage' => capture('codex', rows)) }
  end
end
