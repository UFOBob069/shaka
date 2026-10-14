# frozen_string_literal: true

require 'time'
require_relative 'assessments'

module Shaka
  # Shares the ledger's existing lock and atomic write. Retry identity excludes helper timestamps.
  module LocalReviewTriageHistory
    def assess!(content)
      raise Error, 'Assessment recorded_at is supplied by Shaka.' if content.is_a?(Hash) && content.key?('recorded_at')

      entry = LocalReviewAssessment.new(content)
      locked { append_assessment(entry, content) }
    end

    private

    def append_assessment(entry, content)
      history = LocalReviewAssessments.new(data)
      existing = history.entries.find { |item| item.id == entry.id }
      return assessment_retry!(existing, content) if existing

      history.check_append!(entry)
      write_assessment(history, content)
      entry.id
    end

    def write_assessment(history, content)
      recorded = content.merge('recorded_at' => Time.now.utc.iso8601)
      write(data.merge('version' => LocalReviewBundle::VERSION,
                       'assessments' => history.entries.map(&:data) + [recorded]))
    end

    def record_current!(content)
      @recorded_at = Time.now.utc.iso8601
      LocalReviewAssessment.actor!(content['by']) if content.key?('by')
      updated = recorded_rounds(content)
      LocalReviewAssessments.new(data).check_triage!(updated)
      write(data.merge(content.slice('fallback'), 'version' => LocalReviewBundle::VERSION, 'rounds' => updated))
    end

    def assessment_retry!(existing, content)
      raise Error, "Assessment #{existing.id} already exists with different content; append a correction." unless
        existing.data.except('recorded_at') == content

      existing.id
    end

    def individual(finding, round)
      label = finding['reviewers']&.find do |reviewer, _|
        same_reviewer?(round, reviewer)
      end&.last || finding['reported_as']
      finding.except('reviewers').merge('reported_as' => label).compact
    end

    def solo_claim(finding)
      label = finding['reported_as']
      return [] unless label
      raise Error, 'A solo reported_as must be a short finding number or label.' unless
        label.is_a?(String) && label.match?(LocalReviewLedgerBatch::LABEL)

      [[rounds[batch.first].fetch('reviewer').downcase, label]]
    end

    def preserve_triage(round, mine, actor)
      return round unless mine

      mine = mine.map { |finding| stamped(finding, actor) }
      previous = round['findings']
      return round if unchanged_triage?(previous, mine, actor)

      history = previous ? { 'earlier_findings' => LocalReviewBundle.earlier_findings(round) + [previous] } : {}
      round.merge(history, 'findings' => mine)
    end

    def stamped(finding, actor)
      finding.except('recorded_at', 'by').merge('recorded_at' => @recorded_at).merge(actor ? { 'by' => actor } : {})
    end

    def unchanged_triage?(previous, mine, actor)
      previous && unstamped(previous) == unstamped(mine) && (!actor || previous.all? { |item| item['by'] == actor })
    end

    def unstamped(findings) = findings.map { |finding| finding.except('recorded_at', 'by') }
  end
end
