# frozen_string_literal: true

require_relative '../error'
require_relative '../publication/text'
require_relative 'ledger_settings'

module Shaka
  # Which ledger rounds form the last batch: the reviewers that read the last reviewed commit.
  module LocalReviewLedgerBatch
    include LocalReviewLedgerSettings

    USAGE = %w[model tokens cost estimate].freeze
    # A reviewer's own finding number or short label, such as `1` or `P2-3`.
    LABEL = /\A[\w.-]{1,20}\z/

    private

    def select_record_batch!(head)
      raise Error, 'The ledger has no round to record.' if rounds.empty?

      @record_head = head
      raise Error, 'No review batch matches --head.' if batch.empty?
    end

    # An older batch may be closed after review, but cannot bypass the next-run fix checks.
    def check_historical_fixes!(updated)
      return if !@record_head || @record_head == last_head

      reviewed = rounds.drop(batch.last + 1).map { |round| round.fetch('head') }
      fixes = recorded_batch_fixes(updated) - recorded_batch_fixes
      raise Error, 'An earlier batch fix must name a later reviewed commit; review the fix before recording it.' unless
        (fixes - reviewed).empty?
    end

    def check_batch_recorded!
      unrecorded = batch.find { |index| !recorded?(rounds[index]) }
      raise Error, "Record round #{unrecorded + 1}'s findings with `shaka review record` before the next round." if
        unrecorded
    end

    # Another reviewer may join the last batch until it is triaged; any other repeat of a commit
    # needs a fix first.
    def check_new_head!(head, reviewer)
      reviewed = rounds.index { |round| round['head'] == head && !joins?(round, head, reviewer) }
      raise Error, "Round #{reviewed + 1} already reviewed #{head}; commit the fix first." if reviewed
      return unless head == last_head && batch.any? { |index| rounds[index].key?('findings') }

      raise Error, "#{head}'s findings are already recorded; start every reviewer of a commit before recording."
    end

    # Every round of the last batch gets the findings its reviewer reported, from one triage.
    # A record without `findings` adds usage and keeps the findings already recorded.
    def recorded_rounds(content)
      findings = content.key?('findings') ? PublicationText.list(content['findings'], 'recorded finding') : nil
      # One triage lists each problem once, so an id repeated across reviewers is two problems.
      check_recorded_findings!(findings) if findings
      check_usage!(content)
      updated = rounds.each_with_index.map do |round, index|
        batch.include?(index) ? triaged(round, index, findings, content) : round
      end
      check_historical_fixes!(updated)
      updated
    end

    def triaged(round, index, findings, content)
      mine = findings&.select { |finding| reported?(finding, round) }&.map { |finding| individual(finding, round) }
      usage = merged_usage(round, content)
      round = preserve_triage(round, mine, content['by']).merge(usage)
      check_findings!(round, index + 1)
      round
    end

    def merged_usage(round, content)
      usage = usage_for(content, round['reviewer'])
      # A later native record can replace the placeholder, but never known round attribution.
      return usage if round['model'] == 'UNKNOWN' && known_model?(usage['model'])

      usage.merge(round.slice('model'))
    end

    def known_model?(model) = model.is_a?(String) && !model.strip.empty? && model != 'UNKNOWN'

    # With one round, a finding need not name its reviewer.
    def reported?(finding, round)
      named = finding['reviewers']
      named.nil? ? batch.one? : named.keys.any? { |reviewer| same_reviewer?(round, reviewer) }
    end

    # The copy of a collated finding kept in one reporter's round, with that reviewer's own number.
    # Each finding maps every reviewer that reported it to that reviewer's own finding number, and
    # no reviewer's number is claimed twice. With each reviewer's `FINDINGS n` matched, every
    # individual finding then belongs to exactly one collated finding.
    def check_collation!(findings)
      claimed = findings.flat_map { |finding| claims(finding) }
      repeated = claimed.tally.find { |_, count| count > 1 }&.first
      raise Error, "#{repeated.first} finding ##{repeated.last} is collated into two findings." if repeated
    end

    def claims(finding)
      named = finding['reviewers']
      return solo_claim(finding) if named.nil? && batch.one?

      mapping!(finding['id'], named)
      named.map { |reviewer, label| [reviewer.downcase, label] }
    end

    def mapping!(id, named)
      raise Error, "Finding #{id} must map each reviewer that reported it to that reviewer's finding number." unless
        named.is_a?(Hash) && !named.empty? && named.values.all? { |label| label.is_a?(String) && label.match?(LABEL) }

      check_reviewers!(id, named.keys)
    end

    def check_reviewers!(id, named)
      stray = named.reject { |reviewer| batch.any? { |index| same_reviewer?(rounds[index], reviewer.to_s) } }
      return if stray.empty?

      raise Error, "#{id == 'usage' ? 'Usage' : "Finding #{id}"} names #{stray.join(', ')}, which did not review " \
                   "#{last_head}."
    end

    # Usage for one reviewer's round: under `usage` by reviewer, or at the top level for one round.
    def usage_for(content, reviewer)
      named = (content['usage'] || {}).find { |name, _| name.casecmp?(reviewer) }&.last
      (named || (batch.one? ? content : {})).slice(*USAGE)
    end

    # Usage that fits no round would be dropped, so refuse it instead.
    def check_usage!(content)
      usage = content['usage']
      raise Error, "Put each reviewer's usage under `usage`, keyed by reviewer." if
        (!batch.one? || content.key?('usage')) && content.keys.intersect?(USAGE)
      return unless content.key?('usage')
      raise Error, 'Record usage must map each reviewer to its usage.' unless
        usage.is_a?(Hash) && usage.values.all?(Hash)

      check_reviewers!('usage', usage.keys)
    end

    def check_recorded_findings!(findings)
      LocalReviewFinding.list(findings.map { |finding| finding.is_a?(Hash) ? finding.except('reviewers') : finding },
                              'recorded finding')
      check_collation!(findings)
    end

    def same_reviewer?(round, reviewer) = round['reviewer'].to_s.casecmp?(reviewer.to_s)
  end
end
