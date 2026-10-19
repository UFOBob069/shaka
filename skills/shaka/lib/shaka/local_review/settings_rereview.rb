# frozen_string_literal: true

require_relative '../error'

module Shaka
  # A published round's settings digest groups the rounds of one commit the ledger triaged together.
  # A later group on the same commit is a settings re-review: its earlier review evidence was
  # superseded by a settings change. The digest is local comparison data, so it never appears in
  # the comment.
  module LocalReviewSettingsRereview
    DIGEST = /\A\h{64}\z/

    # Several reviewers may read one commit, listed together, each once per settings group.
    def self.check!(rounds)
      invalid = rounds.find { |round| round.settings && !round.settings.to_s.match?(DIGEST) }
      raise Error, "Round #{invalid.number} settings must be a SHA-256 digest." if invalid

      check_repeats!(rounds)
    end

    def self.check_repeats!(rounds)
      raise Error, 'Two rounds review the same commit with the same reviewer; each round reviews a new head.' unless
        rounds.uniq { |round| [*round.batch, round.reviewer] }.size == rounds.size

      listed_together!(rounds.map(&:head))
      listed_together!(rounds.map(&:batch))
    end

    def self.listed_together!(keys)
      groups = keys.chunk(&:itself).map(&:first)
      raise Error, 'Rounds of one commit must be listed together.' unless groups.uniq.size == groups.size
    end

    def self.mark!(rounds)
      rounds.each_with_index do |round, index|
        earlier = rounds.take(index).select { |other| other.head == round.head }
        round.rereview! if earlier.any? { |other| other.batch != round.batch }
      end
    end

    def settings = @spec['settings']

    def batch = [head, settings]

    def rereview! = (@rereview = true)

    def label = @rereview ? ' · settings re-review' : ''
  end
end
