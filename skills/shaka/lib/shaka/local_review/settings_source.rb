# frozen_string_literal: true

require_relative '../configuration'

module Shaka
  # Selects the one settings source a local review or checkpoint reads.
  module LocalReviewSettingsSource
    private

    def trusted_review
      return @trusted_review if defined?(@trusted_review)

      ref = @options[:criteria_ref]
      @trusted_review = (trusted_review_settings(ref) if ref && trusted_seam?(ref))
    end

    # Repository instructions stay trusted; explicit selection replaces configuration.
    def settings_ref
      return unless @options[:criteria_ref]

      Configuration::SettingsPreview.ref(root:) || @options[:criteria_ref]
    end

    # One source per task: a selected settings PR, else shared settings on the default branch,
    # else complete individual settings. Individual settings never join a shared source.
    def effective_review
      return @effective_review if defined?(@effective_review)

      ref = settings_ref
      @effective_review = if ref == @options[:criteria_ref]
                            trusted_review || individual_review
                          else
                            trusted_review_settings(ref)
                          end
    end

    # Reached only without shared settings; a private tree beside shared settings is never complete.
    def individual_review
      ref = @options[:criteria_ref]
      return unless ref

      source = Configuration.private_source(root:, ref:)
      return unless source.status == 'complete'

      @individual_review = true
      source.candidate_config.review
    end

    # Reads only the review section, so the rest of the seam need not be valid for a review to run;
    # `shaka seam check` validates the whole contract.
    def trusted_review_settings(ref)
      Configuration.review_at_commit(root:, ref:, git: git_executable, capture: method(:capture),
                                     probe: method(:bounded_git))
    end

    # A commit without either configuration keeps the default instructions; invalid sources fail closed.
    def trusted_seam?(ref)
      Configuration.contract_at_commit?(root:, ref:, git: method(:bounded_git))
    end
  end
end
