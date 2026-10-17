# frozen_string_literal: true

require 'securerandom'
require_relative 'budget_ledger'

module Shaka
  module Evaluation
    # A shared monthly account with nightly, PR, or explicitly capped manual scopes.
    class Budget
      class Stopped < StandardError
      end

      attr_reader :kind

      def initialize(directory:, kind:, limits:, **options)
        @limits = BudgetLimits.parse(limits)
        raise ArgumentError, 'Invalid budget options' unless
          BudgetLimits::KINDS.include?(kind) && (options.keys - %i[scope cap clock]).empty?

        @kind = kind
        @clock = options.fetch(:clock, -> { Time.now.utc })
        @scope = scope(options[:scope])
        @cap = cap(options[:cap])
        @ledger = BudgetLedger.new(directory)
      end

      def reserve
        @ledger.transaction do |calls|
          period = month
          raise Stopped, 'unaccounted_trial' if calls.values.any? { it['dollars'].nil? }
          raise Stopped, 'monthly_cap' if monthly(calls, period) >= @limits.fetch('monthly')
          raise Stopped, 'scope_cap' if scoped(calls) >= @cap

          id = SecureRandom.uuid
          [id, { 'version' => 1, 'event' => 'start', 'id' => id, 'month' => period,
                 'kind' => @kind, 'scope' => @scope, 'cap' => BudgetLimits.text(@cap) }]
        end
      end

      def settle(id:, dollars:, digest:)
        amount = BudgetLimits.amount(dollars)
        @ledger.transaction do |calls|
          call = calls.fetch(id)
          raise BudgetError, 'Foreign budget reservation' unless call['kind'] == @kind && call['scope'] == @scope

          over = monthly(calls, call['month']) + amount > @limits.fetch('monthly') || scoped(calls) + amount > @cap
          [over, { 'version' => 1, 'event' => 'settle', 'id' => id,
                   'dollars' => BudgetLimits.text(amount), 'digest' => digest }]
        end
      rescue ArgumentError, KeyError
        raise BudgetError, 'Invalid budget settlement'
      end

      def snapshot
        @ledger.transaction do |calls|
          monthly_total = monthly(calls, month)
          [{ 'monthly_dollars' => BudgetLimits.text(monthly_total),
             'scope_dollars' => BudgetLimits.text(scoped(calls)),
             'pending' => calls.values.count { it['dollars'].nil? }, 'cap' => BudgetLimits.text(@cap),
             'over' => monthly_total > @limits.fetch('monthly') || scoped(calls) > @cap }, nil]
        end
      end

      private

      def month = @clock.call.utc.strftime('%Y-%m')

      def scope(requested)
        return @clock.call.utc.strftime('%F') if @kind == 'nightly' && requested.nil?
        raise ArgumentError, 'Invalid budget scope' unless
          @kind != 'nightly' && requested.is_a?(String) && !requested.strip.empty?

        requested
      end

      def cap(requested)
        raise ArgumentError, 'Manual execution needs an explicit cap' if @kind == 'manual' && requested.nil?

        maximum = @limits.fetch(@kind == 'manual' ? 'monthly' : @kind)
        value = requested.nil? ? maximum : BudgetLimits.amount(requested)
        raise ArgumentError, 'Requested cap exceeds configured maximum' if value > maximum

        value
      end

      def monthly(calls, period) = sum(calls) { it['month'] == period }
      def scoped(calls) = sum(calls) { it['kind'] == @kind && it['scope'] == @scope }
      def sum(calls, &) = calls.values.select(&).sum(Rational(0)) { it['dollars'] || 0 }
    end
  end
end
