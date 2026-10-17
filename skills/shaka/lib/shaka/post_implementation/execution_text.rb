# frozen_string_literal: true

module Shaka
  # Renders the checkpoint's prompt source and native token usage for its closed details.
  module PostImplementationExecutionText
    TOKEN_FIELDS = [%w[input input_tokens], ['cached input', 'cached_input_tokens'],
                    ['cache writes', 'cache_write_input_tokens'], %w[output output_tokens],
                    ['reasoning output', 'reasoning_output_tokens'], %w[total total_tokens]].freeze

    private

    # A prompt pinned to a commit links to that exact file.
    def prompt_text
      source = @result.fetch('prompt_source')
      ref, path = source.split(':', 2)
      return source unless ref.match?(/\A\h{40}\z/) && path && !path.empty?

      "[`#{path}`](https://github.com/#{@repository}/blob/#{ref}/#{path})"
    end

    # One line per configuration keeps the token evidence without a raw record dump.
    def usage_text
      return 'Native usage: UNKNOWN (no readable provider record).' if @usage.empty?

      @usage.group_by { |entry| entry['configuration'] }.map do |configuration, entries|
        counts = TOKEN_FIELDS.map { |label, field| "#{token_total(entries, field)} #{label}" }
        "Native usage (#{Array(configuration).join(' · ')}), #{entries.size} " \
          "#{entries.size == 1 ? 'response' : 'responses'}: #{counts.join(', ')}."
      end.join("\n\n")
    end

    def token_total(entries, field)
      values = entries.map { |entry| entry['usage'].is_a?(Hash) ? entry['usage'][field] : nil }
      return 'UNKNOWN' unless values.all? { |value| value.is_a?(Integer) && value >= 0 }

      values.sum.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
    end
  end
end
