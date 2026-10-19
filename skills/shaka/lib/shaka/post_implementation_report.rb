# frozen_string_literal: true

require 'json'
require_relative 'error'

module Shaka
  # Product conclusions never use the technical REVIEWED attestation.
  module PostImplementationReport
    CONCLUSIONS = ['Proceed', 'Simplify/reframe', 'Do not merge'].freeze
    # The task owner's dispositions, shared by the owner's checkpoint comment and the description headline.
    RECOMMENDATIONS = ['Merge', 'Revise before merge', 'Reconsider approach', 'Do not merge'].freeze
    # Whether the verification proves the intent; only inadequate stops an agent merge, never readiness.
    ADEQUACY = ['adequate', 'adequate with accepted gaps', 'inadequate', 'cannot judge'].freeze
    ADEQUACY_FIELDS = %w[verdict weakest_claim next_check].freeze
    # The packet's intent says what the change rests on; its verification says what was proved.
    ADEQUACY_CONTRACT = 'verification_adequacy (an object judging whether the packet verification proves the ' \
                        "packet intent: verdict, one of #{ADEQUACY.map(&:to_json).join(', ')}; " \
                        'adequate means the checks reach what safe_because rests on and not_verified leaves ' \
                        'nothing material; adequate with accepted gaps means the named gaps are acceptable ' \
                        'for review_effort; inadequate means the safety claim has no check that reaches it; ' \
                        'cannot judge means the checks do not show what ran; weakest_claim, the claim the ' \
                        'evidence supports least; next_check, the one check that would most raise confidence).'.freeze

    module_function

    def read(path, head:)
      text = File.binread(path, 100_001)
      raise Error, 'Checkpoint report exceeds 100 KB' if text.bytesize > 100_000

      report = JSON.parse(text)
      validate(report, head:)
      report.slice('head', 'conclusion', 'reasons', 'concerns', 'alternative', 'summary', 'next_action')
            .merge('verification_adequacy' => report['verification_adequacy'].slice(*ADEQUACY_FIELDS))
    rescue JSON::ParserError => e
      raise Error, "Malformed checkpoint report: #{e.message}"
    end

    def validate(report, head:)
      raise Error, 'Checkpoint report must be an object for the current head' unless
        report.is_a?(Hash) && report['head'] == head
      raise Error, 'Checkpoint report has an invalid conclusion' unless CONCLUSIONS.include?(report['conclusion'])

      evidence_fields!(report)
      summary_fields!(report)
      adequacy!(report['verification_adequacy'])
    end

    # Single lines, because the checkpoint comment renders them inline.
    def adequacy!(adequacy)
      raise Error, "Checkpoint verification_adequacy needs #{ADEQUACY_FIELDS.join(', ')}" unless
        adequacy.is_a?(Hash) && ADEQUACY_FIELDS.all? { |key| text?(adequacy[key]) && !adequacy[key].match?(/[\r\n]/) }
      raise Error, "Checkpoint verification_adequacy verdict must be one of: #{ADEQUACY.join(', ')}" unless
        ADEQUACY.include?(adequacy['verdict'])
    end

    def evidence_fields!(report)
      %w[reasons concerns].each { |key| strings!(report[key], key) }
      raise Error, 'Checkpoint needs reasons and a simpler alternative' if
        report['reasons'].empty? || !text?(report['alternative'])
    end

    def summary_fields!(report)
      %w[summary next_action].each do |key|
        raise Error, "Checkpoint #{key} must be non-empty text" if report.key?(key) && !text?(report[key])
      end
    end

    def strings!(list, label)
      raise Error, "Checkpoint #{label} must be a list of non-empty strings" unless
        list.is_a?(Array) && list.all? { |entry| text?(entry) }
    end

    def text?(value) = value.is_a?(String) && !value.strip.empty?
    def ready?(report) = report['conclusion'] == 'Proceed' && report['concerns'].empty?
  end
end
