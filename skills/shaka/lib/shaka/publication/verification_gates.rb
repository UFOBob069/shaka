# frozen_string_literal: true

module Shaka
  # Writes the repository validation and local review line from their bound results, so no
  # check has to restate them and no paraphrase can call a failed run a pass.
  module VerificationGates
    LABEL = '**Validation and review:**'
    UNKNOWN = "#{LABEL} UNKNOWN: no validation or review results were supplied for this revision.".freeze

    module_function

    # Binding accepts a completed run whatever its exit, so the exit code decides the wording here.
    def line(verdict, review_url = nil)
      return UNKNOWN unless verdict

      validation, reviews = %w[validation review].map do |kind|
        Array(verdict.dig('checks', kind)).map { |entry| entry['original'] }
      end
      "#{LABEL} #{[*validations(validation), review(reviews, review_url)].join('; ')} at `#{verdict['head'][0, 7]}`."
    end

    def validations(results)
      results.map do |result|
        code = result['exit_code']
        "`#{result['command']}` #{code&.zero? ? 'passed' : 'failed'} (exit #{code})"
      end
    end

    # A host review is only reported by its attestation; a CLI review was launched by the helper.
    def review(results, url)
      reviewers = results.map do |result|
        result['status'] == 'reported' ? "#{result['reviewer']} (host-reported)" : result['reviewer']
      end
      text = "local review by #{reviewers.join(', ')}"
      url ? "#{text} ([attestation](#{url}))" : text
    end

    private_class_method :validations, :review
  end
end
