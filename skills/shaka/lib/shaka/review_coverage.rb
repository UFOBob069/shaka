# frozen_string_literal: true

require_relative 'error'
require_relative 'defaults'
require_relative 'publication/text'
require_relative 'reviewer_selection'

module Shaka
  # review.provider_coverage names providers each change should get a review from. Shaka then runs
  # one local reviewer per listed provider in place of review.local_review_count, and names each one
  # that could not review, with the reason; a gap never blocks. Writing a change is not reviewing
  # it, so the implementing provider gets no credit.
  module ReviewCoverage
    KEY = 'provider_coverage'
    COUNT = 'local_review_count'
    NOT_LISTED = 'not listed in review.local_review_agents'
    UNAVAILABLE = ReviewerSelection::UNAVAILABLE
    NOT_SET_UP = ReviewerSelection::NOT_SET_UP

    # Selection compares these with each reviewer's provider, folding case.
    def self.validate!(review)
      return unless review.key?(KEY)

      providers!(review[KEY])
      return if review[KEY].empty? || !review.key?(COUNT)

      raise Error, "review.#{KEY} runs one reviewer per listed provider; remove review.#{COUNT}"
    end

    # How many local reviewers run on each commit.
    def self.count(review)
      providers = names(setting(review, KEY))
      providers.empty? ? setting(review, COUNT) : providers.size
    end

    # A review setting, or its packaged default.
    def self.setting(review, key) = review.fetch(key) { Defaults.fetch('review', key) }

    # The entries selection chooses from: for each covered provider, its first listed entry that
    # can run here, or its first entry when none can, so the gap keeps that entry's reason.
    def self.candidates(entries, providers, usable)
      return entries if names(providers).empty?

      chosen = names(providers).filter_map do |name|
        own = entries.select { |entry| entry['provider'].downcase == name }
        own.find(&usable) || own.first
      end
      entries.select { |entry| chosen.include?(entry) }
    end

    def self.names(providers) = providers.map(&:downcase).uniq

    def self.providers!(providers)
      unless providers.is_a?(Array) && providers.all? { |provider| name?(provider) }
        raise Error, "review.#{KEY} must be a list of provider names such as openai"
      end

      repeated = providers.map(&:downcase).tally.find { |_, count| count > 1 }
      raise Error, "review.#{KEY} repeats #{repeated.first}" if repeated
    end

    def self.name?(value) = value.is_a?(String) && value.match?(%r{\A[^/\s]+\z})

    # Reads the `reviewers` run order and the `considered` reasons `ReviewerSelection` returns.
    def self.coverage(providers, selection)
      names = names(providers)
      reviewed = selection.fetch('reviewers').map { |id| provider(id) }
      gaps = (names - reviewed).map do |name|
        { 'provider' => name, 'reason' => reason(listed_reasons(selection, name)) }
      end
      { 'providers' => names, 'gaps' => gaps }
    end

    def self.listed_reasons(selection, name)
      listed = selection.fetch('considered').select { |entry| provider(entry.fetch('reviewer')) == name }
      listed.map { |entry| entry.fetch('reason') }
    end

    # A listed provider that can run always reviews, so its gap is a missing or failed setup.
    def self.reason(reasons)
      return NOT_LISTED if reasons.empty?

      reasons.all?(NOT_SET_UP) ? NOT_SET_UP : UNAVAILABLE
    end

    # The `provider_coverage` object copied from `shaka reviewer`. Every listed provider that did
    # not review the final commit is a gap, whether or not the copy named it, so a selected reviewer
    # that failed afterward still shows. The copied gaps supply only reasons; a stale one, such as
    # for a provider whose fallback reviewer ran after selection, is ignored.
    def self.notice(coverage, reviewed, redact:)
      return [] if coverage.nil?

      providers = listed(coverage)
      reviewed = reviewed.map { |id| provider(id) }
      reasons = reasons(coverage['gaps'], redact)
      gaps = (providers - reviewed).map { |name| gap_text(name, reasons[name]) }
      gaps.empty? ? [] : ["**Review coverage gap:** #{gaps.join(' ')}"]
    end

    def self.listed(coverage)
      raise Error, 'provider_coverage must be an object.' unless coverage.is_a?(Hash)

      providers!(coverage['providers'])
      names(coverage['providers'])
    end

    def self.reasons(gaps, redact)
      PublicationText.list(gaps, 'provider_coverage gaps').to_h do |gap|
        raise Error, 'Each coverage gap must be an object.' unless gap.is_a?(Hash)

        [PublicationText.single_line(gap['provider'], 'coverage gap provider').downcase,
         PublicationText.single_line(gap['reason'], 'coverage gap reason').sub(redact, '[path]')]
      end
    end

    def self.gap_text(name, reason)
      "no local review of this commit from `#{name}` (#{reason || 'reason not recorded'})."
    end

    def self.provider(id) = id.split('/').first.downcase
    private_class_method :providers!, :name?, :listed_reasons, :reason, :listed, :reasons, :gap_text,
                         :provider
  end
end
