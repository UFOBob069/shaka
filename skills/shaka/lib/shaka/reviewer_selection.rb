# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Chooses which local reviewers to run on one head.
  #
  # What makes a review adversarial is the context, not the model: a fresh session that did not
  # produce the change reviews it honestly, even when it runs the model that wrote it. So there is
  # no disqualifying identity here and no blocker. A different provider is preferred because
  # different providers notice different things, and the implementation model in a fresh context is
  # an ordinary answer when no other is available. When a round runs several reviewers, the first
  # still prefers a different provider and the rest follow the maintainer's list order.
  class ReviewerSelection
    IDENTITY = %w[provider model_family].freeze
    SUPPORTED_REVIEWERS = %w[openai/codex anthropic/claude xai/grok deepseek/openrouter].freeze
    AVAILABLE = 'available'
    UNAVAILABLE = 'unavailable'
    SAME_PROVIDER = 'same provider as the implementation'
    NOTES = {
      'different_provider' => 'Run %s: a provider that did not implement this.',
      'same_provider' => 'Run %s: no other provider is available, and its context is still fresh.',
      'same_model' => 'No listed reviewer is available. Run %s in a fresh context, which is a ' \
                      'valid review, and the GitHub reviews still run on the pushed branch.'
    }.freeze

    def self.parse(text)
      provider, family, extra = text.to_s.split('/', -1)
      parts = [provider, family]
      valid = extra.nil? && parts.all? do |part|
        part.is_a?(String) && part.strip.match?(/\A[^[:space:]]+(?: [^[:space:]]+)*\z/)
      end
      raise Error, "Reviewer identity must be PROVIDER/MODEL_FAMILY: #{text}" unless valid

      { 'provider' => provider.strip, 'model_family' => family.strip }
    end

    def initialize(reviewers:, implementers:, unavailable: [], count: 1)
      @reviewers = reviewers || []
      @implementers = implementers
      @unavailable = unavailable
      @count = count
    end

    def call
      raise Error, 'At least one implementer identity is required.' if @implementers.empty?
      raise Error, 'The reviewer count must be at least 1.' unless @count.is_a?(Integer) && @count.positive?

      reasons = @reviewers.map { |entry| [entry, reason(entry)] }
      selected = pick(reasons)
      verdict(selected, reasons)
    end

    private

    # Prefer a provider that did not implement the change; otherwise any available entry will do.
    def pick(reasons)
      [AVAILABLE, SAME_PROVIDER].each do |wanted|
        found = reasons.find { |_, why| why == wanted }
        return found.first if found
      end
      nil
    end

    def reason(entry)
      return UNAVAILABLE if unavailable?(entry)
      return SAME_PROVIDER if providers.include?(fold(entry['provider']))

      AVAILABLE
    end

    def verdict(selected, reasons)
      outcome = outcome_for(selected, reasons)
      {
        'outcome' => outcome,
        'reviewer' => reviewer_for(outcome, selected),
        'reviewers' => run_order(selected, reasons),
        'implementation_providers' => providers,
        'considered' => reasons.map { |entry, why| { 'reviewer' => identity(entry), 'reason' => why } },
        'note' => note(outcome, selected)
      }
    end

    def outcome_for(selected, reasons)
      return reasons.assoc(selected).last == AVAILABLE ? 'different_provider' : 'same_provider' if selected

      # A failed implementation-model CLI does not rule out a fresh host context.
      'same_model'
    end

    # The preferred reviewer first, then other available entries in list order up to the count.
    def run_order(selected, reasons)
      return [implementer] unless selected

      others = reasons.reject { |entry, why| entry.equal?(selected) || why == UNAVAILABLE }.map(&:first)
      [selected, *others].first(@count).map { |entry| identity(entry) }
    end

    def reviewer_for(outcome, selected)
      return identity(selected) if selected
      return implementer if outcome == 'same_model'

      nil
    end

    # Prefer an implementer with a working CLI; any implementer can still review in a fresh host context.
    def available_implementer = @implementers.find { |entry| !unavailable?(entry) }

    def note(outcome, selected)
      template = NOTES.fetch(outcome)
      return template unless template.include?('%s')

      format(template, selected ? identity(selected) : implementer)
    end

    def unavailable?(entry)
      @unavailable.any? { |blocked| key(blocked) == key(entry) }
    end

    # Compare components and fold case: an identity read from display metadata may be spelled
    # differently than the seam spells it, and a miss would pick a less preferred reviewer.
    def key(entry) = entry.values_at(*IDENTITY).map { |part| fold(part) }

    def fold(value) = value.to_s.downcase

    def providers = @providers ||= @implementers.map { |entry| fold(entry['provider']) }.uniq

    def implementer = identity(available_implementer || @implementers.first)

    def identity(entry) = entry.values_at(*IDENTITY).join('/')
  end
end
