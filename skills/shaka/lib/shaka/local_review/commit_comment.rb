# frozen_string_literal: true

require_relative 'comment'
require_relative 'attention'

module Shaka
  # One timeline entry, validated against the complete loop so slicing cannot hide invalid fixes.
  class LocalReviewCommitComment < LocalReviewComment
    def initialize(content, head:, subject:, usage_url: nil, **)
      super(content, **)
      @history = @rounds
      @rounds = @history.select { |round| round.head == head }
      @before = @history.take_while { |round| round.head != head }
      @subject = subject
      @usage_url = usage_url
    end

    def key = "local-review-#{@rounds.last.head}"

    def render
      attention = LocalReviewAttention.new(@before + @rounds, @links)
      blocks = [TITLE, "**Reviewed revision:** #{@links.commit(@rounds.last.head)}", *attention.visible,
                coverage, usage_link, *fallback_notice, *settings_notice, *bound,
                history(attention), @rounds.last.attestation]
      "#{blocks.join("\n\n")}\n"
    end

    private

    def coverage
      groups = @rounds.group_by { |round| round.value('coverage') || 'UNKNOWN; see evidence.' }
      values = groups.map { |text, rounds| "#{rounds.map(&:reviewer).join(', ')}: #{text}" }
      "**Coverage:** #{values.join(' · ')}"
    end

    def coverage_reports
      lines = @rounds.map do |round|
        value = round.value('coverage') || 'UNKNOWN; inspect the original report for limitations.'
        reported = round.reported_coverage || 'UNKNOWN; inspect the original report for complete coverage limits.'
        text = "- #{round.reviewer}: #{value}"
        "#{text}\n\n**Unverified report excerpt · #{round.reviewer}:**\n\n<pre>#{CGI.escapeHTML(reported)}</pre>"
      end
      "**Review coverage:**\n\n" \
        "Coverage excerpts may be incomplete or misidentified; inspect the original reports.\n\n#{lines.join("\n")}"
    end

    def usage_link
      return 'Usage and attribution: see the PR description.' unless @usage_url

      "[Usage and attribution](#{@usage_url}) in the PR description."
    end

    def history(attention)
      blocks = ["<details>\n<summary>Review evidence and history</summary>",
                "**Commit:** #{@subject.call(@rounds.last.head)}", *attention.details, coverage_reports,
                '### Execution metadata', table,
                *LocalReviewTriage.details(@rounds), '</details>']
      blocks.join("\n\n")
    end

    def disclosure_count = @rounds.size + 1

    def summaries_in_order?(html)
      outer = html.index('<summary>Review evidence and history</summary>')
      first = html.index("<summary>#{@rounds.first.summary}</summary>")
      outer && first && outer < first && super
    end

    # Only the final entry can announce that the loop reached its bound.
    def bound
      @rounds.last.head == @history.last.head ? LocalReviewBound.new(@history, @max_rounds).lines : []
    end
  end
end
