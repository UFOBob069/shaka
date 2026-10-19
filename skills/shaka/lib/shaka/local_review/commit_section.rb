# frozen_string_literal: true

require 'cgi'
require_relative 'triage'

module Shaka
  # One reviewed commit's collapsed evidence: its subject, coverage excerpts, and original reports.
  class LocalReviewCommitSection
    def initialize(rounds, subject, links)
      @rounds = rounds
      @subject = subject
      @links = links
    end

    attr_reader :rounds

    def head = @rounds.first.head

    # The commit, labeled when these rounds re-reviewed it after a settings change.
    def link = "#{@links.commit(head)}#{@rounds.first.label}"

    def summaries = [summary, *@rounds.map(&:summary)]

    def to_s
      ["<details>\n<summary>#{summary}</summary>", "**Commit:** #{@links.commit(head)} #{@subject.call(head)}",
       coverage_reports, *LocalReviewTriage.details(@rounds), '</details>'].join("\n\n")
    end

    private

    def summary
      count = @rounds.sum { |round| round.findings.size }
      reviewers = @rounds.map(&:reviewer).join(', ')
      PublicationText.summary_text("Commit #{head[0, 7]}#{@rounds.first.label} · #{reviewers} · " \
                                   "#{count} #{count == 1 ? 'finding' : 'findings'}", 'commit summary')
    end

    def coverage_reports
      lines = @rounds.map do |round|
        value = round.value('coverage') || 'UNKNOWN; inspect the original report for limitations.'
        reported = round.reported_coverage || 'UNKNOWN; inspect the original report for complete coverage limits.'
        "- #{round.reviewer}: #{value}\n\n**Unverified report excerpt · #{round.reviewer}:**\n\n" \
          "<pre>#{literal(reported)}</pre>"
      end
      "**Review coverage:**\n\n" \
        "Coverage excerpts may be incomplete or misidentified; inspect the original reports.\n\n#{lines.join("\n")}"
    end

    # A pipe written as an entity displays the same, and keeps a table in the excerpt from
    # reaching the rendering check as one GitHub failed to render.
    def literal(text) = CGI.escapeHTML(text).gsub('|', '&#124;')
  end
end
