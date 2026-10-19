# frozen_string_literal: true

require_relative 'harbor_trial'
require_relative 'decision_replay'

module Shaka
  module Evaluation
    # Tier 1 uses the same reservation, native capture and cleanup as artifact trials.
    class DecisionTrial < HarborTrial
      def initialize(expected_actions:, **)
        super(**)
        @expected_actions = expected_actions
        valid = @expected_actions.is_a?(Hash) && @expected_actions.all? do |id, expected|
          @tasks.key?(id) && DecisionReplay.valid_expected?(expected)
        end
        raise ArgumentError, 'Expected task IDs and ordered decision actions' unless valid
      end

      private

      def planned?(task)
        task.is_a?(Hash) && task['tier'] == 1 && @tasks.key?(task['id']) &&
          @expected_actions.key?(task['id']) && RunRecord.task_errors(task).empty?
      end

      def grade(record, capture)
        DecisionReplay.apply(record, expected: @expected_actions.fetch(record.fetch('task').fetch('id')),
                                     directory: capture.fetch('directory'))
      end
    end
  end
end
