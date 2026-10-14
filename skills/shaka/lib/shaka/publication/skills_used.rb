# frozen_string_literal: true

require_relative 'text'

module Shaka
  # Records are supplied by the task owner; Ruby checks shape, not the evidence's truth.
  class SkillsUsed
    SUMMARY = 'Skills used'
    FIELDS = %w[name source revision phase contribution evidence corroboration].freeze
    LABELS = { 'agent-reported' => 'Agent-reported', 'corroborated' => 'Corroborated' }.freeze
    NOTE = 'Agent-reported use is the agent’s account. The agent selects Corroborated when a record confirms ' \
           'invocation or loading. Shaka does not check that record or instruction compliance. ' \
           'Completeness is not verified.'

    def self.refuse_free_form!(items)
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.casecmp?(SUMMARY) }

      raise Error, 'Publication Skills used must be supplied as skills_used, not a details item.'
    end

    def initialize(records)
      @records = PublicationText.list(records, 'skills_used')
    end

    def detail
      rows = @records.map { |record| row(record) }.uniq
      body = rows.empty? ? 'No skill use recorded; coverage is UNKNOWN.' : table(rows)
      { 'summary' => SUMMARY, 'body' => "#{body}\n\n#{NOTE}" }
    end

    private

    def table(rows)
      header = %w[Skill Source Revision Phase Contribution Evidence Corroboration]
      [header, ['---'] * header.size, *rows].map { |cells| "| #{cells.join(' | ')} |" }.join("\n")
    end

    def row(record)
      unless record.is_a?(Hash) && record.keys.all?(String) && record.keys.sort == FIELDS.sort
        raise Error, 'Publication skills_used record fields do not match the metadata allowlist.'
      end

      evidence = LABELS.fetch(record['evidence']) { raise Error, 'Publication skills_used evidence is invalid.' }
      cells = %w[name source revision phase contribution].map { |field| cell(record[field], field) }
      [*cells, evidence, corroboration(record)]
    end

    def corroboration(record)
      return cell(record['corroboration'], 'corroboration') if record['evidence'] == 'corroborated'
      return '—' if record['corroboration'].nil?

      raise Error, 'Publication agent-reported skill use requires null corroboration.'
    end

    def cell(value, field)
      PublicationText.table_cell(PublicationText.summary_text(value, "skills_used #{field}"))
    end
  end
end
