# frozen_string_literal: true

require_relative '../post_implementation_report'
require_relative 'publication'

module Shaka
  # The task owner's shipping recommendation, separate from the reviewer's verification.
  module PostImplementationDisposition
    RECOMMENDATIONS = ['Merge', 'Revise before merge', 'Reconsider approach', 'Do not merge'].freeze

    module_function

    def read(content, head:, report:)
      validate(content, head:)
      raise Error, 'Merge disposition cannot override a blocking conclusion or unresolved concerns' if
        merge?(content) && !PostImplementationReport.ready?(report)

      content.slice('head', 'recommendation', 'reason', 'next_action')
    end

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
      ["Recommended next action: **#{disposition.fetch('recommendation')}**", @summary,
       "**Next action (task owner):** #{disposition.fetch('next_action')}",
       "Evaluation: **#{report.fetch('conclusion')}**", verification,
       evidence_lines(report), supporting_analysis(report, verification)].join("\n\n")
    end

    def evidence_lines(report)
      ["Head: `#{@head}`",
       "Unresolved concerns: #{report.fetch('concerns').empty? ? 'none' : report.fetch('concerns').join('; ')}",
       'Required checks, reviews, and merge authority still apply.'].join("\n\n")
    end

    def incomplete_body
      raise Error, 'PR disposition requires completed verification; publish the execution result first'
    end
  end
end
