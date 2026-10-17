# frozen_string_literal: true

require_relative '../post_implementation_report'
require_relative '../publication/text'
require_relative '../usage/codex_usage'
require_relative '../usage/claude_usage'
require_relative 'evidence'
require_relative 'publisher_identity'
require_relative 'execution_text'
require_relative '../github/squash_comment'

module Shaka
  # Presents the checkpoint's action without confusing configuration with observations.
  class PostImplementationPublication
    include PostImplementationPublisherIdentity
    include PostImplementationExecutionText

    attr_reader :state

    def summary = @summary || PublicationText.required(@result.fetch('reason'), 'checkpoint failure reason')

    ACTIONS = {
      'Proceed' => ['Merge if CI passes', 'Complete technical validation and required approvals.'],
      'Simplify/reframe' => ['Revise before merge', 'Revise the approach, then revalidate and review.'],
      'Do not merge' => ['Do not merge; decide whether to close or replace',
                         'Bring the close-or-replace decision to the maintainer.']
    }.freeze
    SCOPE = 'Ruby checked this report\'s format and commit; the reviewer judged value, not correctness. ' \
            'Required checks, reviews, and merge authority still apply.'

    def initialize(result, head:, repository:, message: nil)
      @result = result
      @head = head
      @message = message
      @repository = repository
      @revision = "[`#{head[0, 7]}`](https://github.com/#{repository}/commit/#{head})"
      @usage = native_usage
      @configuration = @usage.last&.fetch('configuration') || []
    end

    def render
      @state = @result['status'] == 'opted_out' ? 'opted_out' : 'not_completed'
      body = @result['status'] == 'completed' ? completed_body : incomplete_body
      body += "\n\n#{squash_details}" if @state == 'ready'
      "#{identity}\n\n# Checkpoint for #{@revision}\n\n#{body}\n\n#{"#{@disposition_line}\n" if @disposition_line}" +
        PostImplementationEvidence.attestation(@head, @state)
    end

    private

    def execution_evidence = "#{model_text} · #{effort_text}"

    def model_text
      observed = known(@configuration[2])
      configured = known(@configuration[1])
      requested = known(@result['requested_model'])
      parts = ["observed model: #{observed || 'UNKNOWN'}"]
      parts << "configured model: #{configured}" if configured && configured != observed
      parts << "requested model: #{requested}" if requested && ![observed, configured].include?(requested)
      parts.join('; ')
    end

    def effort_text
      recorded = known(@configuration[3])
      requested = known(@result['effort'])
      parts = ["recorded effort: #{recorded || 'UNKNOWN'}"]
      parts << "requested effort: #{requested}" if requested && requested != recorded
      parts.join('; ')
    end

    def known(value) = (value.strip if value.is_a?(String) && !value.strip.empty? && !value.strip.casecmp?('UNKNOWN'))

    def completed_body
      report = PostImplementationReport.read(@result.fetch('report'), head: @head)
      @state = PostImplementationReport.ready?(report) ? 'ready' : 'blocked'
      action, next_action = recommendation(report)
      summary = @summary = report.fetch('summary', report.fetch('reasons').first)
      ["## Reviewer recommendation: #{action}", "**Next:** #{owner_action(report, next_action)}",
       verdict(report, summary), supporting_analysis(report, summary)].join("\n\n")
    end

    # One paragraph states the verdict and its evidence; the concern list follows only when there is one.
    # Only a ready verdict says no concerns remain, so a blocking verdict never reads as clear to merge.
    def verdict(report, summary)
      verdict = PostImplementationReport.ready?(report) ? 'Proceed, no unresolved concerns' : report.fetch('conclusion')
      items = report.fetch('concerns')
      list = "\n\n**Unresolved concerns:**\n\n#{items.map { |item| "- #{item}" }.join("\n")}" unless items.empty?
      "**Reviewer verdict:** #{verdict}.#{" #{summary}" if summary}#{list}"
    end

    def squash_details
      "<details>\n<summary>Squash commit message</summary>\n\n#{SquashComment.body(@head, @message.call)}\n</details>"
    end

    # A lead paragraph, such as the reviewer summary an owner decision moves out of view, opens the details.
    def supporting_analysis(report, summary, lead: nil)
      ["<details>\n<summary>Supporting analysis and execution details</summary>", *lead,
       *report.fetch('reasons').reject { |reason| reason == summary },
       "Alternative considered: #{report.fetch('alternative')}",
       "#{execution_evidence} · prompt: #{prompt_text}", usage_text, SCOPE, '</details>'].join("\n\n")
    end

    def recommendation(report)
      if report['conclusion'] == 'Proceed' && !report['concerns'].empty?
        return ['Resolve concerns before merging', 'Resolve substantive concerns, then repeat affected review.']
      end

      ACTIONS.fetch(report.fetch('conclusion'))
    end

    def owner_action(report, fallback)
      return fallback unless report['conclusion'] == 'Proceed' && report['concerns'].empty?

      report.fetch('next_action', fallback)
    end

    def incomplete_body
      heading, next_action = if @result['status'] == 'opted_out'
                               ['Checkpoint opted out; no product review completed',
                                'Verify opt-out authority and remaining gates.']
                             else
                               ['Checkpoint not completed; readiness remains blocked',
                                'Resolve the execution failure and rerun the checkpoint.']
                             end
      "## #{heading}\n\n#{summary}\n\n**Next:** #{next_action}\n\n" \
        "<details>\n<summary>Execution details</summary>\n\n#{execution_evidence}\n\n#{usage_text}\n\n</details>"
    end

    def native_usage
      return [] unless @result['usage']

      reader = @result['reviewer'] == 'openai/codex' ? CodexUsage : ClaudeUsage
      source = reader.new([@result['usage']], [], all_turns: true)
      source.responses.values.map { |entry| entry.slice('configuration', 'usage') }
    end
  end
end
