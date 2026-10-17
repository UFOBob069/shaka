# frozen_string_literal: true

module Shaka
  module Evaluation
    class BudgetError < StandardError
    end

    # Exact dollar values supplied by the operator; no implicit spending limits.
    module BudgetLimits
      KINDS = %w[nightly pr manual].freeze

      module_function

      def amount(value)
        raise ArgumentError, 'Invalid dollar amount' unless value.is_a?(Numeric) || value.is_a?(String)

        text = value.to_s
        raise ArgumentError, 'Invalid dollar amount' unless text.match?(/\A\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\z/)

        Rational(text)
      end

      def text(value)
        whole, remainder = value.numerator.divmod(value.denominator)
        digits = +''
        until remainder.zero?
          digit, remainder = (remainder * 10).divmod(value.denominator)
          digits << digit.to_s
        end
        "#{whole}.#{digits.empty? ? '0' : digits}"
      end

      def parse(limits)
        raise ArgumentError, 'Invalid budget limits' unless
          limits.is_a?(Hash) && limits.keys.sort == %w[monthly nightly pr]

        limits.transform_values { amount(it) }
      end
    end
  end
end
