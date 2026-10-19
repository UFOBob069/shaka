# frozen_string_literal: true

require_relative '../error'
require_relative 'finding'

module Shaka
  # A round run with `--settings-ref` records a digest of the settings whose change supersedes its
  # review evidence. Rounds of one commit under one digest form a batch, so after those settings
  # change, such as when the installed Shaka updates mid-task, the last reviewed commit can be
  # reviewed again as a new batch instead of in a new commit or a new ledger.
  module LocalReviewLedgerSettings
    # The digest of the review under way, which its round records.
    attr_writer :settings

    private

    def with_settings(round) = @settings ? round.merge('settings' => @settings) : round

    # Indexes of the rounds that reviewed the last head under its newest settings.
    def batch
      head = @record_head || last_head
      key = rounds.reverse.find { |round| round['head'] == head }&.values_at('head', 'settings')
      rounds.each_index.select { |index| rounds[index].values_at('head', 'settings') == key }
    end

    # Joining needs the last batch's settings; a round of an earlier batch on the commit does not block it.
    def joins?(round, head, reviewer)
      head == last_head && @settings == rounds.last['settings'] &&
        (round['settings'] != @settings || !same_reviewer?(round, reviewer))
    end

    # Whether this round starts a new batch on the last head. A record of that head reaches only its
    # newest batch, so the earlier findings must be settled first.
    def new_settings_batch?(head)
      return false unless head == last_head && @settings != rounds.last['settings']

      unless settings_rereview?(head)
        raise Error, "#{head} was reviewed under other settings; give every reviewer of a commit the same " \
                     '--settings-ref.'
      end

      unsettled = recorded_findings(head).find { |finding| finding.open? || finding.fixed? }
      raise Error, "Settle finding #{unsettled.id}, or review its fix, before a settings re-review of #{head}." if
        unsettled

      true
    end

    def recorded_findings(head)
      rounds.select { |round| round['head'] == head }
            .flat_map { |round| LocalReviewFinding.list(round['findings'], 'recorded finding') }
    end

    # The last reviewed commit under settings no round on it recorded. Every earlier round on it must
    # carry settings, or nothing shows they changed.
    def settings_rereview?(head)
      return false unless @settings && head == last_head

      earlier = rounds.select { |round| round['head'] == head }.map { |round| round['settings'] }
      earlier.all? && !earlier.include?(@settings)
    end
  end
end
