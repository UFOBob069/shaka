# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/evaluation_budget_fixture'
require_relative '../eval/lib/shaka/evaluation/budget'

class EvaluationBudgetProcessTest < Minitest::Test
  include EvaluationBudgetFixture

  LIBRARY = File.expand_path('../eval/lib/shaka/evaluation/budget', __dir__)
  CHILD = <<~RUBY
    require ARGV.shift
    account = Shaka::Evaluation::Budget.new(directory: ARGV.shift, kind: 'nightly',
      limits: { 'monthly' => 200, 'nightly' => 5, 'pr' => 15 },
      clock: -> { Time.utc(2026, 10, 16, 20) })
    begin
      account.reserve
      puts 'reserved'
    rescue Shaka::Evaluation::Budget::Stopped => e
      puts e.message
    end
  RUBY

  def child(code = CHILD)
    Open3.capture3(RbConfig.ruby, '-e', code, LIBRARY, File.join(@directory, 'budget'))
  end

  def test_concurrent_processes_can_reserve_only_one_unaccounted_call
    outputs = Array.new(2) { Thread.new { child } }.map(&:value)
    assert(outputs.all? { |_, _, status| status.success? })
    assert_equal %w[reserved unaccounted_trial], outputs.map { |out, _, _| out.strip }.sort
    assert_equal 1, budget.snapshot.fetch('pending')
  end

  def test_hard_process_exit_leaves_a_durable_reservation
    _output, _error, status = child("#{CHILD}\nexit! 99")
    assert_equal 99, status.exitstatus
    error = assert_raises(Shaka::Evaluation::Budget::Stopped) { budget.reserve }
    assert_equal 'unaccounted_trial', error.message
  end
end
