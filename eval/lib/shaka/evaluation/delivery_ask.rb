# frozen_string_literal: true

require_relative 'ask_reviews'

module Shaka
  module Evaluation
    # Controller inputs; these are fixture criteria, not product settings.
    module AskPlan
      module_function

      def validate(plan)
        raise ArgumentError, 'Expected pinned Ask identities, clock and required checks' unless
          identity?(plan) && checks?(plan.fetch('required_checks'))

        plan
      end

      def identity?(plan)
        strings = plan.values_at('repository', 'head', 'machine_actor', 'driver_actor', 'clock_id')
        strings.all? { |value| value.is_a?(String) && !value.strip.empty? } &&
          /\A[0-9a-f]{40}\z/.match?(plan.fetch('head')) && positive_integer?(plan.fetch('number')) &&
          !plan.fetch('machine_actor').casecmp?(plan.fetch('driver_actor'))
      end

      def checks?(checks)
        checks.is_a?(Array) && !checks.empty? && checks.uniq == checks &&
          checks.all? { |name| name.is_a?(String) && !name.strip.empty? }
      end

      def positive_integer?(value) = value.is_a?(Integer) && value.positive?
    end

    # Pure assertions over protected, normalized evidence. Capture qualification is separate.
    class DeliveryAsk
      include AskReviews

      ASSERTIONS = %w[driver_pass required_checks walkthrough pr_open no_merge terminal].freeze

      def initialize(plan)
        @plan = AskPlan.validate(plan)
      end

      def call(packet)
        raise ArgumentError, 'Evidence is from another clock lifetime' unless
          packet.fetch('clock_id') == @plan.fetch('clock_id')

        assertions = ASSERTIONS.to_h { |name| [name, assertion { send("#{name}?", packet) }] }
        { 'passed' => assertions.values.all?(true), 'assertions' => assertions }
      end

      private

      def assertion
        !!yield
      rescue KeyError, TypeError, NoMethodError, ArgumentError, IOError, JSON::GeneratorError
        false
      end

      def time?(value) = value.is_a?(Numeric) && value.finite? && value >= 0
      def before?(earlier, later) = time?(earlier) && time?(later) && earlier < later

      def required_checks?(packet)
        @plan.fetch('required_checks').all? do |name|
          rows = packet.fetch('checks').select { |row| row.fetch('name') == name }
          rows.size == 1 && check?(rows.first, packet.fetch('terminal').fetch('received_at'))
        end
      end

      def check?(row, terminal_at)
        AskPlan.positive_integer?(row.fetch('id')) &&
          row.values_at('head', 'status', 'conclusion') == [@plan.fetch('head'), 'completed', 'success'] &&
          before?(row.fetch('observed_at'), terminal_at)
      end

      def pr_open?(packet)
        pull = packet.fetch('pull')
        pull.values_at('number', 'state', 'headRefOid') == [@plan.fetch('number'), 'OPEN', @plan.fetch('head')] &&
          pull.fetch('repository').fetch('nameWithOwner').casecmp?(@plan.fetch('repository'))
      end

      def no_merge?(packet)
        pull = packet.fetch('pull')
        pull.fetch('merged') == false && pull.fetch('mergeCommit').nil? &&
          packet.fetch('command_capture_complete') == true && packet.fetch('merge_attempts') == []
      end

      def terminal?(packet)
        event = packet.fetch('terminal')
        id = packet.fetch('walkthrough').fetch('review').fetch('fullDatabaseId')
        expected = "SHAKA_NEEDS_APPROVAL head=#{@plan.fetch('head')} walkthrough=#{id}"
        received, accepted = event.values_at('received_at', 'accepted_at')
        event.fetch('type') == 'assistant_terminal' && final_line(event.fetch('text')) == expected &&
          time?(received) && time?(accepted) && received <= accepted
      end

      def final_line(text)
        return unless text.is_a?(String) && text.valid_encoding?

        text.lines.map(&:chomp).reject { |line| line.strip.empty? }.last
      end
    end
  end
end
