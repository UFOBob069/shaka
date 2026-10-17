# frozen_string_literal: true

require_relative 'budget'
require_relative 'record_store'

module Shaka
  module Evaluation
    # One executor call at a time; finishing a batch is not a quality or release verdict.
    class Runner
      def initialize(budget:, directory:)
        @budget = budget
        @store = RecordStore.new(directory)
      end

      def run(tasks, &executor)
        plans = plans(tasks, executor)
        @completed = 0
        @spent = Rational(0)
        @active = false
        execute(plans, executor)
      end

      private

      def plans(tasks, executor)
        raise ArgumentError, 'Expected tasks and an executor' unless tasks.is_a?(Array) && !tasks.empty? && executor

        tasks.map do |task|
          raise ArgumentError, 'Invalid task or automatic tier 3 execution' unless valid_task?(task)

          JSON.parse(JSON.generate(task))
        end
      end

      def valid_task?(task)
        RunRecord.task_errors(task).empty? && (task['tier'] != 3 || @budget.kind == 'manual')
      end

      def execute(plans, executor)
        iterate(plans, executor)
      rescue Budget::Stopped => e
        @active = true if e.message == 'unaccounted_trial'
        report(@active ? 'harness_error' : 'partial', e.message)
      rescue StandardError
        report('harness_error', @active ? 'unaccounted_trial' : 'budget_unavailable')
      end

      def iterate(plans, executor)
        plans.each do |task|
          record = trial(task, executor)
          return report('harness_error', 'executor_harness_error') if record.dig('outcome', 'state') == 'HARNESS_ERROR'
          return report('partial', 'cap_exceeded') if @over
        end
        report('complete', 'finished')
      end

      def trial(task, executor)
        id = @budget.reserve
        @active = true
        record = executor.call(JSON.parse(JSON.generate(task)), id)
        record, digest = @store.write(record, id: id, task: task)
        @over = @budget.settle(id: id, dollars: record.dig('usage', 'cache_neutral_dollars'), digest: digest)
        completed(record)
        record
      end

      def completed(record)
        @spent += BudgetLimits.amount(record.dig('usage', 'cache_neutral_dollars'))
        @completed += 1
        @active = false
      end

      def report(status, reason)
        { 'status' => status, 'completed' => @completed,
          'dollars' => @active ? 'UNKNOWN' : BudgetLimits.text(@spent), 'reason' => reason }
      end
    end
  end
end
