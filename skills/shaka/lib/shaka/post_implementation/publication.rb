# frozen_string_literal: true

require_relative '../post_implementation_report'
require_relative '../publication/text'
require_relative '../usage/codex_usage'
require_relative '../usage/claude_usage'
require_relative 'evidence'

module Shaka
  # Presents the checkpoint's action without confusing configuration with observations.
  class PostImplementationPublication
    ACTIONS = {
      'Proceed' => ['Merge if CI passes',
                    'Complete technical validation and required approvals.'],
      'Simplify/reframe' => ['Revise before merging.', 'Revise the approach, then revalidate and review.'],
      'Do not merge' => ['Do not merge; decide whether to close or replace.',
                         'Bring the close-or-replace decision to the maintainer.']
    }.freeze

    def initialize(result, head:)
      @result = result
      @head = head
      @usage = native_usage
      @configuration = @usage.last&.fetch('configuration') || []
    end

    def render
      @state = @result['status'] == 'opted_out' ? 'opted_out' : 'not_completed'
      body = @result['status'] == 'completed' ? completed_body : incomplete_body
      "#{identity}\n\n# Post-implementation validation\n\n#{body}\n\n" +
        PostImplementationEvidence.attestation(@head, @state)
    end

    private

    def identity
      provider, family = @result.fetch('reviewer', 'UNKNOWN/UNKNOWN').split('/', 2)
      PublicationText.identity('agent' => family, 'provider' => provider,
                               'model' => headline_model, 'effort' => known(@configuration[3]))
    end

    def headline_model
      known(@configuration[2]) || known(@configuration[1])&.then { |model| "#{model} (configured)" }
    end

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

    def known(value)
      value.strip if value.is_a?(String) && !value.strip.empty? && !value.strip.casecmp?('UNKNOWN')
    end

    def completed_body
      report = PostImplementationReport.read(@result.fetch('report'), head: @head)
      @state = PostImplementationReport.ready?(report) ? 'ready' : 'blocked'
      action, next_action = recommendation(report)
      summary = report.fetch('summary', report.fetch('reasons').first)
      ["Recommendation: **#{action}**", summary,
       "**Next action (task owner):** #{owner_action(report, next_action)}",
       "Head: `#{@head}`",
       "Unresolved concerns: #{report.fetch('concerns').empty? ? 'none' : report.fetch('concerns').join('; ')}",
       supporting_analysis(report, summary)].join("\n\n")
    end

    def supporting_analysis(report, summary)
      ["<details>\n<summary>Supporting analysis and execution details</summary>",
       "Conclusion: **#{report.fetch('conclusion')}**",
       *report.fetch('reasons').reject { |reason| reason == summary },
       "Alternative considered: #{report.fetch('alternative')}",
       execution_evidence, "Prompt: #{@result.fetch('prompt_source')}.", usage_text,
       'Ruby verified report shape and head binding. The reviewer judged value; the task owner handles concerns ' \
       'and merge readiness. This does not attest to technical review.', '</details>'].join("\n\n")
    end

    def recommendation(report)
      if report['conclusion'] == 'Proceed' && !report['concerns'].empty?
        return ['Resolve concerns before merging.', 'Resolve substantive concerns, then repeat affected review.']
      end

      ACTIONS.fetch(report.fetch('conclusion'))
    end

    def owner_action(report, fallback)
      return fallback unless report['conclusion'] == 'Proceed' && report['concerns'].empty?

      report.fetch('next_action', fallback)
    end

    def incomplete_body
      action, next_action = if @result['status'] == 'opted_out'
                              ['Checkpoint opted out; no product review completed.',
                               'Verify opt-out authority and remaining gates.']
                            else
                              ['Review not completed; readiness remains blocked.',
                               'Resolve the execution failure and rerun the checkpoint.']
                            end
      "Recommendation: **#{action}**\n\n#{@result.fetch('reason')}\n\n" \
        "**Next action (task owner):** #{next_action}\n\nHead: `#{@head}`\n\n" \
        "<details>\n<summary>Execution details</summary>\n\n#{execution_evidence}\n\n#{usage_text}\n\n</details>"
    end

    def usage_text
      return 'Native usage: UNKNOWN (no readable provider record).' if @usage.empty?

      "```json\n#{JSON.pretty_generate(@usage)}\n```"
    end

    def native_usage
      return [] unless @result['usage']

      reader = @result['reviewer'] == 'openai/codex' ? CodexUsage : ClaudeUsage
      source = reader.new([@result['usage']], [], all_turns: true)
      source.responses.values.map { |entry| entry.slice('configuration', 'usage') }
    end
  end
end
