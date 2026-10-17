# frozen_string_literal: true

require_relative 'ledger'
require_relative '../publication/usage_details'

module Shaka
  # Keeps the existing redacted usage record, never a transcript, with its review round.
  module LocalReviewUsage
    METRICS = { 'input' => 'input', 'cached_input' => 'cached input', 'cache_writes' => 'cache writes',
                'output' => 'output', 'reasoning_output' => 'reasoning output' }.freeze

    module_function

    # Saved results carry the same redacted records as their ledger, including earlier heads.
    def attach(content, result_path)
      return content unless result_path

      captured = Array(result_path).flat_map { |path| result_rounds(path) }.filter_map { |round| round['usage_record'] }
      return content if captured.empty?

      usage = content.fetch('usage', { 'note' => '', 'records' => [] })
      records = (captured + usage.fetch('records')).each_with_object([]) { |record, kept| keep_record(kept, record) }
      content.merge('usage' => usage.merge('records' => records))
    end

    # Use the same response coverage rules as description carry, including copies of a source.
    def keep_record(kept, record)
      identity = UsageRecordCarry.identity!(record)
      return if kept.any? { |earlier| equivalent?(earlier, record) }

      known = kept.reject { |earlier| unknown?(earlier) }.map { |earlier| UsageRecordCarry.identity!(earlier) }
      return if covered?(record, identity, known)

      kept.reject! { |earlier| replaces?(earlier, record, identity) }
      kept << record
    end

    def equivalent?(left, right)
      left == right || (left.fetch('responses').any? && left.except('sources') == right.except('sources'))
    end

    def replaces?(earlier, record, identity)
      previous = UsageRecordCarry.identity!(earlier)
      UsageRecords.superseded?(previous, [identity]) ||
        (unknown?(earlier) && !unknown?(record) && same_source?(previous, identity))
    end

    def covered?(record, identity, known)
      known.include?(identity) || UsageRecords.superseded?(identity, known) ||
        (unknown?(record) && known.any? { |earlier| same_source?(identity, earlier) })
    end

    def same_source?(left, right)
      left['host'] == right['host'] && UsageRecords.same_attribution?(left, right) &&
        UsageRecords.fallback_match?(left, right)
    end

    # An unreadable refresh cannot replace retained usage or attribution.
    def unknown?(record)
      record.fetch('columns').all? { |column| column.except('label').values.all?('UNKNOWN') }
    end

    def result_rounds(path)
      result = JSON.parse(File.read(path, encoding: 'UTF-8'))
      return result.fetch('usage_records').map { |record| { 'usage_record' => record } } if result.key?('usage_records')

      ledger = result['ledger']
      ledger && File.file?(ledger) ? LocalReviewLedger.new(ledger).rounds : [result]
    end

    def tokens(record)
      record.fetch('columns').map do |column|
        values = METRICS.map do |key, label|
          value = column.fetch(key)
          value = UsageNumbers.grouped(value.to_i) if value.match?(/\A\d+\z/)
          "#{value} #{label}"
        end.join('; ')
        record['columns'].one? ? values : "#{column.fetch('label')}: #{values}"
      end.join(' · ')
    end

    def cost(record)
      UsageRows.new(record.fetch('columns')).summary || 'cost UNKNOWN'
    end
  end
end
