# frozen_string_literal: true

require 'json'

module Shaka
  module Evaluation
    # Original and repricing inputs come from the same read; source logs are never edited.
    module UsageSnapshot
      module_function

      def write(directory, host, files)
        files.each_with_index.map do |file, index|
          source = File.read(file, encoding: 'UTF-8')
          repriced, identities = transform(source, host)
          original = File.join(directory, "original-#{index}.jsonl")
          neutral = File.join(directory, "neutral-#{index}.jsonl")
          File.write(original, source, mode: 'wx', perm: 0o600)
          File.write(neutral, repriced, mode: 'wx', perm: 0o600)
          [original, neutral, identities]
        end.transpose
      end

      def transform(source, host)
        rows = source.each_line.map { |line| parse(line) }
        identities = rows.filter_map { |row| identity(row, host) }
        rows.each { |row| neutralize(row, host) }
        [rows.map { |row| JSON.generate(row) }.join("\n"), identities]
      end

      def parse(line)
        row = JSON.parse(line)
        unless row.is_a?(Hash) && row['type'].is_a?(String) && row['type'] != 'result'
          raise ArgumentError, 'Expected native JSONL'
        end

        row
      end

      def identity(row, host)
        response = host == 'codex' ? codex_response(row) : claude_response(row)
        return unless response

        id = response.fetch(host == 'codex' ? 'response_id' : 'id')
        raise ArgumentError, 'Unidentified native response' unless id.is_a?(String) && !id.strip.empty?

        id
      end

      def codex_response(row)
        row.fetch('payload') if row['type'] == 'token_usage_record'
      end

      def claude_response(row)
        row.fetch('message') if row['type'] == 'assistant' && row.dig('message', 'model') != '<synthetic>'
      end

      def neutralize(row, host)
        if host == 'codex' && row['type'] == 'token_usage_record'
          codex(row.fetch('payload').fetch('usage'))
        elsif host == 'claude-code' && row['type'] == 'assistant' && row.dig('message', 'model') != '<synthetic>'
          claude(row.fetch('message').fetch('usage'))
        end
      end

      def codex(usage)
        input, cached, writes = counters(usage, %w[input_tokens cached_input_tokens cache_write_input_tokens])
        raise ArgumentError, 'Inconsistent native counters' if cached + writes > input

        usage['cached_input_tokens'] = usage['cache_write_input_tokens'] = 0
        usage.delete('native_cost_usd')
        usage.delete('native_cost_source')
      end

      def claude(usage)
        names = %w[input_tokens cache_read_input_tokens cache_creation_input_tokens]
        usage['input_tokens'] = counters(usage, names).sum
        usage['cache_read_input_tokens'] = usage['cache_creation_input_tokens'] = 0
        usage['cache_creation'] = { 'ephemeral_5m_input_tokens' => 0, 'ephemeral_1h_input_tokens' => 0 }
      end

      def counters(usage, names)
        values = usage.values_at(*names)
        raise ArgumentError, 'Incomplete native counters' unless values.all? do |value|
          value.is_a?(Integer) && value >= 0
        end

        values
      end
    end
  end
end
