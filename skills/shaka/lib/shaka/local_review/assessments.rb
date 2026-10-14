# frozen_string_literal: true

require_relative 'assessment'
require_relative 'bundle'

module Shaka
  # Interprets only explicit judgments. Superseded entries remain in the retained record.
  class LocalReviewAssessments
    ATTENTION = %w[action_required decision_required].freeze
    attr_reader :entries

    def initialize(content)
      @rounds = content.fetch('rounds')
      @entries = PublicationText.list(content['assessments'], 'assessments').map do |entry|
        LocalReviewAssessment.new(entry)
      end
      seen = []
      entries.each do |entry|
        raise Error, 'Assessment IDs must be unique and supersede only earlier entries.' if
          seen.include?(entry.id) || (entry.supersedes - seen).any?

        seen << entry.id
      end
    end

    def active
      superseded = entries.flat_map(&:supersedes)
      entries.reject { |entry| superseded.include?(entry.id) }
    end

    def for_finding(id) = active.select { |entry| entry.finding == id }

    def attention?(id)
      conflict?(id) || for_finding(id).any? do |entry|
        ATTENTION.include?(entry.data['attention']) || !available?(entry)
      end
    end

    def conflict?(id)
      for_finding(id).combination(2).any? { |left, right| disagree?(left, right) }
    end

    def available?(entry, rounds = @rounds)
      found = rounds.any? { |round| round.fetch('findings', []).any? { |finding| finding['id'] == entry.finding } }
      found && (!entry.recommendation || recommendation_available?(entry, rounds))
    end

    def historically_available?(entry)
      rounds = @rounds.map do |round|
        kept = LocalReviewBundle.earlier_findings(round).flatten(1) + round.fetch('findings', [])
        round.merge('findings' => kept)
      end
      available?(entry, rounds)
    end

    def check_append!(entry)
      raise Error, 'Assessment references an unavailable finding or recommendation.' unless available?(entry)
      raise Error, 'Assessment supersedes must name earlier entries in this ledger.' unless
        (entry.supersedes - entries.map(&:id)).empty? && !entry.supersedes.include?(entry.id)
    end

    def check_triage!(updated)
      missing = active.find { |entry| available?(entry) && !available?(entry, updated) }
      return unless missing

      raise Error,
            "Assessment #{missing.id} still references this finding or reviewer mapping; supersede it first."
    end

    private

    def recommendation_available?(entry, rounds)
      ref = entry.recommendation
      rounds.any? do |round|
        round['head'] == ref['head'] && round['reviewer'].casecmp?(ref['reviewer']) &&
          round.fetch('findings', []).any? do |finding|
            finding['id'] == entry.finding && finding['reported_as'] == ref['reported_as']
          end
      end
    end

    def disagree?(left, right)
      a = left.data
      b = right.data
      return true if different?(a, b, 'problem')
      return false if left.recommendation && right.recommendation && left.recommendation != right.recommendation

      other_judgments_differ?(a, b)
    end

    def other_judgments_differ?(left, right)
      %w[remedy implementation attention].any? { |key| different?(left, right, key) } ||
        %w[taken commits attribution].any? do |key|
          different?(left.fetch('action', {}), right.fetch('action', {}), key)
        end
    end

    def different?(left, right, key) = left.key?(key) && right.key?(key) && left[key] != right[key]
  end
end
