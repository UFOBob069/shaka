# frozen_string_literal: true

module Shaka
  # Format checks for references and times; availability is checked against the ledger separately.
  module LocalReviewAssessmentReferences
    DATE = /\A\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2}))?\z/

    private

    def check_references!
      self.class.sha!(data['revision'], 'revision') if data.key?('revision')
      recommendation!(recommendation) if data.key?('recommendation')
      check_lists!
    end

    def check_lists!
      list!(supersedes, 'supersedes').each { |id| identifier!(id, 'supersedes') }
      list!(data.fetch('evidence', []), 'evidence').each { |item| evidence!(item) }
    end

    def recommendation!(value)
      raise Error, 'Assessment recommendation needs head, reviewer, and reported_as.' unless
        value.is_a?(Hash) && value.keys.sort == %w[head reported_as reviewer]

      self.class.sha!(value['head'], 'recommendation head')
      %w[reviewer reported_as].each { |key| PublicationText.single_line(value[key], "recommendation #{key}") }
      raise Error, 'Assessment recommendation reviewer must be a lowercase provider/family.' unless
        value['reviewer'].match?(%r{\A[a-z0-9_-]+/[a-z0-9_-]+\z})
    end

    def list!(value, field)
      raise Error, "Assessment #{field} must be a list without duplicates." unless
        value.is_a?(Array) && value.uniq == value

      value
    end

    def evidence!(value)
      return if value.is_a?(String) && value.match?(LocalReviewEvidence::SHA)

      uri = URI.parse(value.to_s)
      return if value.is_a?(String) && https_link?(uri)

      raise Error, 'Assessment evidence must contain HTTPS links or full SHAs.'
    rescue URI::InvalidURIError
      raise Error, 'Assessment evidence must contain HTTPS links or full SHAs.'
    end

    def https_link?(uri) = uri.is_a?(URI::HTTPS) && uri.host && !uri.userinfo

    def date!(value, field)
      raise Error, "Assessment #{field} must be an ISO date or timestamp." unless
        value.is_a?(String) && value.match?(DATE)

      Date.iso8601(value[0, 10])
      Time.iso8601(value) if value.include?('T')
    rescue ArgumentError
      raise Error, "Assessment #{field} must be an ISO date or timestamp."
    end
  end
end
