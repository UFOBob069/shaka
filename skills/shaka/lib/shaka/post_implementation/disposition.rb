# frozen_string_literal: true

require_relative '../post_implementation_report'
require_relative 'publication'

module Shaka
  # The task owner's shipping recommendation, separate from the reviewer's verification.
  module PostImplementationDisposition
    RECOMMENDATIONS = PostImplementationReport::RECOMMENDATIONS

    module_function

    def read(content, head:, report:)
      validate(content, head:)
      accepted = accepted_concerns(content, report)
      raise Error, 'Merge disposition cannot override a blocking conclusion or unresolved concerns' if
        merge?(content) && !PostImplementationReport.ready?(report.merge('concerns' => unresolved(report, accepted)))

      content.slice('head', 'recommendation', 'reason', 'next_action').merge('accepted_concerns' => accepted)
    end

    # Checks that each acceptance names one listed concern and records a decision, not who decided.
    def accepted_concerns(content, report)
      entries = content.fetch('accepted_concerns', [])
      raise Error, 'PR disposition accepted_concerns needs each concern and a one-line decision without < or `' unless
        entries.is_a?(Array) && entries.all? { |entry| acceptance?(entry) }

      listed_once!(entries.map { |entry| entry['concern'] }, report)
      entries.map { |entry| entry.slice('concern', 'decision') }
    end

    def listed_once!(names, report)
      raise Error, 'PR disposition accepts a concern the checkpoint report does not list, or lists one twice' unless
        names.uniq == names && (names - report.fetch('concerns')).empty?
    end

    # One plain line, so a decision cannot hide or imitate the rest of the published comment.
    def acceptance?(entry)
      entry.is_a?(Hash) && %w[concern decision].all? { |key| PostImplementationReport.text?(entry[key]) } &&
        !entry['decision'].match?(/[\r\n<`]/)
    end

    def unresolved(report, accepted) = report.fetch('concerns') - accepted.map { |entry| entry['concern'] }

    def validate(content, head:)
      raise Error, 'PR disposition must be an object for the verified head' unless
        content.is_a?(Hash) && content['head'] == head
      raise Error, 'PR disposition has an invalid recommendation' unless
        RECOMMENDATIONS.include?(content['recommendation'])

      text_fields!(content)
    end

    def text_fields!(content)
      %w[reason next_action].each do |key|
        raise Error, "PR disposition #{key} must be non-empty text" unless
          PostImplementationReport.text?(content[key])
      end
    end

    def merge?(content) = content['recommendation'] == 'Merge'
  end

  # Publishes an owner decision through the existing checkpoint and readiness attestation.
  class PostImplementationDispositionPublication < PostImplementationPublication
    private

    def completed_body
      report = PostImplementationReport.read(@result.fetch('report'), head: @head)
      disposition = PostImplementationDisposition.read(@result['disposition'], head: @head, report:)
      @state = PostImplementationDisposition.merge?(disposition) ? 'ready' : 'blocked'
      @summary = disposition.fetch('reason')
      verification = report.fetch('summary', report.fetch('reasons').first)
      ["## Recommendation: #{disposition.fetch('recommendation')}", @summary,
       "**Next:** #{disposition.fetch('next_action')}",
       evidence_lines(report, disposition, verification), supporting_analysis(report, verification)].join("\n\n")
    end

    # The hidden disposition line, rendered above the attestation, lets a description read this recommendation.
    def evidence_lines(report, disposition, verification)
      accepted = disposition.fetch('accepted_concerns')
      @disposition_line = PostImplementationEvidence.disposition(disposition.fetch('recommendation'))
      open = report.merge('concerns' => PostImplementationDisposition.unresolved(report, accepted))
      [verdict(open, verification), *accepted_section(accepted)].join("\n\n")
    end

    def accepted_section(accepted)
      return [] if accepted.empty?

      items = accepted.map { |entry| "- #{entry['concern']} — Decision: #{entry['decision']}" }
      ['**Concerns recorded as accepted by the maintainer:** ' \
       "Ruby checked that each records a decision, not who made it.\n\n#{items.join("\n")}"]
    end

    def incomplete_body
      raise Error, 'PR disposition requires completed verification; publish the execution result first'
    end
  end
end
