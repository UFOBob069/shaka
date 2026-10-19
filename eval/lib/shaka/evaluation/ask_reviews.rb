# frozen_string_literal: true

require_relative 'delivery_review'
require_relative 'ask_walkthrough'

module Shaka
  module Evaluation
    # Grade the driver's retained receipts, not an agent's claimed review results.
    module AskReviews
      private

      def driver_pass?(packet)
        entries = packet.fetch('verifications')
        return false unless ordered_verifications?(entries)

        entry = entries.last
        row = review(entry.fetch('receipt'), @plan.fetch('driver_actor'))
        expected = "driver-verification: PASS head=#{@plan.fetch('head')} " \
                   "attempt=#{entry.fetch('attempt')} executions=#{entry.fetch('executions')}"
        row.fetch('body').lines.map(&:strip).grep(/\Adriver-verification:/) == [expected] &&
          verification_timing?(entry, packet.fetch('terminal'))
      end

      def ordered_verifications?(entries)
        counts = entries.map { |entry| entry.fetch('executions') }
        entries.all? { |entry| verification_counts?(entry) } &&
          counts.each_cons(2).all? { |earlier, later| earlier < later }
      end

      def verification_counts?(entry)
        attempt, executions = entry.values_at('attempt', 'executions')
        attempt.is_a?(Integer) && attempt.positive? && executions.is_a?(Integer) && executions >= attempt
      end

      def verification_timing?(entry, terminal)
        post = entry.fetch('post_completed_at')
        finished = entry.fetch('receipt').fetch('readback_finished_at')
        before?(post, finished) && before?(post, terminal.fetch('received_at')) &&
          before?(finished, terminal.fetch('accepted_at'))
      end

      def walkthrough?(packet)
        receipt = packet.fetch('walkthrough')
        current = packet.fetch('current_walkthrough')
        row = review(receipt, @plan.fetch('machine_actor'))
        driver_id = driver_review_id(packet)
        row == review(current, @plan.fetch('machine_actor')) && row.fetch('fullDatabaseId') != driver_id &&
          walkthrough_timing?(receipt, current, packet.fetch('terminal')) &&
          AskWalkthrough.valid?(row.fetch('body'), @plan, packet.fetch('changed_files'))
      end

      def walkthrough_timing?(receipt, current, terminal)
        before?(receipt.fetch('readback_finished_at'), terminal.fetch('received_at')) &&
          before?(terminal.fetch('accepted_at'), current.fetch('readback_finished_at'))
      end

      def driver_review_id(packet)
        packet.fetch('verifications').last.fetch('receipt').fetch('review').fetch('fullDatabaseId')
      end

      def review(receipt, actor)
        row = receipt.fetch('review')
        id = row.fetch('fullDatabaseId')
        raise ArgumentError, 'Expected a native review ID' unless /\A[1-9]\d*\z/.match?(id)

        expected = @plan.slice('repository', 'number', 'head').merge('actor' => actor,
                                                                     'node_id' => row.fetch('id'), 'review_id' => id)
        normalized = DeliveryReview.read(JSON.generate({ 'data' => { 'node' => row } }), expected)
        raise ArgumentError, 'Review digest differs' unless normalized == row

        row
      end
    end
  end
end
