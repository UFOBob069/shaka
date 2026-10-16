# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # Renders what a pull request is for and how it was proved, so a maintainer can decide whether to trust it.
  module IntentVerification
    INTENT = { 'why' => 'Why', 'scope' => 'Scope', 'leaves_out' => 'Leaves out',
               'safe_because' => 'Safe because' }.freeze
    # Like heart-rate zones: the blast radius sets how hard a reviewer should work.
    REVIEW_EFFORT = {
      1 => 'recovery: read the description.',
      2 => 'easy: skim the diff.',
      3 => 'tempo: read the walkthrough and the diff.',
      4 => 'threshold: read every line and run it yourself.',
      5 => 'all out: review every line, reproduce it, and ask a second reviewer.'
    }.freeze
    CHECKS = (1..3)
    # A link opens the evidence and a code span names what ran; plain prose names neither.
    EVIDENCE = %r{\]\(https?://[^)\s]+\)|`[^`]+`}

    module_function

    def render(content)
      checks_allowed = content['wip'].nil? ? CHECKS : (0..CHECKS.max)
      [intent(object(content, 'intent')), verification(object(content, 'verification'), checks_allowed)]
    end

    def intent(spec)
      lines = INTENT.map do |field, label|
        "**#{label}:** #{PublicationText.single_line(spec[field], "intent #{field}")}"
      end
      "## Intent\n\n#{[*lines, review_effort(spec['review_effort'])].join("\n\n")}"
    end

    def review_effort(effort)
      zone = REVIEW_EFFORT[effort] if effort.is_a?(Integer)
      raise Error, 'Publication intent review_effort must be a whole number from 1 to 5.' unless zone

      "**Review effort:** #{effort} of 5, #{zone}"
    end

    def verification(spec, allowed)
      not_verified = PublicationText.single_line(spec['not_verified'], 'verification not_verified')
      ['## Verification', *checks(spec['checks'], allowed), "**Not verified:** #{not_verified}"].join("\n\n")
    end

    # An unfinished draft may have run nothing yet; Not verified then says why.
    def checks(value, allowed)
      listed = PublicationText.list(value, 'verification checks')
      unless allowed.cover?(listed.size)
        raise Error, "Publication verification checks must list #{allowed.min} to #{allowed.max} checks."
      end
      return [] if listed.empty?

      [listed.map { |check| "- #{evidenced(PublicationText.single_line(check, 'verification check'))}" }.join("\n")]
    end

    def evidenced(check)
      return check if check.match?(EVIDENCE)

      raise Error, "Publication verification check needs a Markdown link or a code span: #{check}"
    end

    def object(content, key)
      spec = content[key]
      raise Error, "Publication description requires #{key}." unless spec.is_a?(Hash)

      spec
    end

    private_class_method :intent, :review_effort, :verification, :checks, :evidenced, :object
  end
end
