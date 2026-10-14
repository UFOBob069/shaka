# frozen_string_literal: true

require_relative 'assessment'

module Shaka
  # Unknown legacy metadata stays in the private ledger, never promoted to a public comment.
  module LocalReviewPublicTriage
    FIELDS = %w[id summary class disposition commit note reported_as decision by recorded_at].freeze

    module_function

    def snapshots(value) = value.map { |snapshot| snapshot.map { |finding| project(finding) } }

    def project(value)
      kept = value.slice(*FIELDS)
      normalize_actor(kept)
      kept.delete('recorded_at') if kept.key?('recorded_at') && !recording_time?(kept['recorded_at'])
      kept['unpublished_metadata'] = true unless kept == value
      kept
    end

    def normalize_actor(kept)
      return unless kept.key?('by')

      by = actor(kept['by'])
      by ? kept['by'] = by : kept.delete('by')
    end

    def actor(value)
      return unless value.is_a?(Hash)

      LocalReviewAssessment.actor!(value.slice('name', 'role'))
    rescue Shaka::Error
      nil
    end

    def recording_time?(value)
      value.is_a?(String) && value.match?(LocalReviewAssessmentReferences::DATE)
    end
  end
end
