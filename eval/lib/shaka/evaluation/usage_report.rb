# frozen_string_literal: true

module Shaka
  module Evaluation
    # Converts the installed CLI's display columns; no transcript or source identity escapes.
    module UsageReport
      UNKNOWN = 'UNKNOWN'
      TOKENS = { 'cached_input_tokens' => 'cached_input', 'cache_write_tokens' => 'cache_writes',
                 'output_tokens' => 'output', 'reasoning_tokens' => 'reasoning_output' }.freeze

      module_function

      def normalize(original, neutral, host, expected:)
        columns = original.fetch('columns')
        models = columns.map { |column| model(column, host) }
        priced = eligible?(original, host, expected) && eligible?(neutral, host, expected) &&
                 original.dig('record', 'responses') == neutral.dig('record', 'responses')
        billed = priced ? dollars(columns) : UNKNOWN
        cache_neutral = billed == UNKNOWN ? UNKNOWN : dollars(neutral.fetch('columns'), conservative: true)
        { 'models' => models, 'cache_neutral_dollars' => cache_neutral, 'billed_dollars' => billed }
      end

      def eligible?(report, host, expected)
        record = report.fetch('record')
        responses = record.fetch('responses')
        record['host'] == host && record['complete'] == true && responses.is_a?(Array) &&
          responses.size == expected && expected.positive? &&
          responses.uniq == responses && report['columns'] == record['columns']
      end

      def model(column, host)
        identity = { 'provider' => column.fetch('provider'), 'configured_model' => column.fetch('model'),
                     'routed_model' => column.fetch('routed'), 'effort' => column.fetch('effort') }
        identity['routed_model'] = identity['routed_model'].delete_suffix('-fast') if host == 'claude-code'
        tokens = TOKENS.transform_values { |field| count(column[field]) }
        identity.merge(tokens).merge('input_tokens' => input(column, host))
      end

      def input(column, host)
        fields = host == 'codex' ? %w[input] : %w[input cached_input cache_writes]
        inputs = fields.map { |field| count(column[field]) }
        inputs.include?(UNKNOWN) ? UNKNOWN : inputs.sum
      end

      def count(value)
        value.is_a?(String) && value.match?(/\A\d+\z/) ? value.to_i : UNKNOWN
      end

      def dollars(columns, conservative: false)
        return UNKNOWN unless nonempty_columns?(columns)

        amounts = columns.map { |column| column['usd'] }
        return UNKNOWN unless amounts.all? { |value| amount?(value) }

        # The CLI rounds each column to six decimals. Reserve its upper rounding bound.
        margin = conservative ? Rational(columns.size, 2_000_000) : 0
        (amounts.sum { |value| Rational(value.delete_prefix('$')) } + margin).to_f
      end

      def amount?(value) = value.is_a?(String) && value.match?(/\A\$\d+\.\d{6}\z/)
      def nonempty_columns?(columns) = columns.is_a?(Array) && !columns.empty?
    end
  end
end
