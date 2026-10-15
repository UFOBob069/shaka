# frozen_string_literal: true

require_relative 'comment'
require_relative 'attention'
require_relative 'comment_part'
require_relative 'commit_section'

module Shaka
  # The whole review loop in one comment: the current outcome once, a row per reviewed commit, one
  # disclosure for findings and execution metadata, and each commit's reports collapsed beneath it.
  # When GitHub's size limit cannot hold every report, the oldest commits' reports move into
  # continuation comments; each comment closes with its newest round's attestation, where `merge` reads it.
  class LocalReviewLoopComment < LocalReviewComment
    LIMIT = 65_536
    # Cleanup wraps a continuation in an archive disclosure, so it must fit with room to spare.
    ARCHIVE_ROOM = 2_000
    # Keyed by the ledger's first reviewed commit and its identity, so the same loop republishes in
    # place while a fresh ledger gets its own comment, even from the same commit. A ledger written
    # before identities existed, or a host review's content file, falls back to its first report.
    LOOP_KEY = 'local-review-loop'
    LEDGER_ID = /\A[0-9a-f]{12}\z/
    FINDINGS = 'Findings, assessments, and execution metadata'

    def initialize(content, subject: ->(_) { 'Commit subject unavailable.' }, usage_url: nil, **)
      super(content, **)
      @ledger_id = content['id']
      raise Error, 'Local review ledger id must be 12 hexadecimal characters.' unless
        @ledger_id.nil? || @ledger_id.to_s.match?(LEDGER_ID)

      @usage_url = usage_url
      @commits = @rounds.chunk(&:head).map { |_, rounds| LocalReviewCommitSection.new(rounds, subject) }
      @attention = LocalReviewAttention.new(@rounds, @links, assessments: @assessment_view)
    end

    def render = parts.first.body

    # This ledger's reports of one commit, which a comment it replaces must contain.
    def reports(head) = @rounds.select { |round| round.head == head }.map(&:published_report)

    def key = "#{LOOP_KEY}-#{@rounds.first.head[0, 12]}-#{@ledger_id || @rounds.first.report_digest[0, 12]}"

    # The main comment first, keeping the newest commits' reports that fit; the rest follow, oldest first.
    def parts
      (0...@commits.size).each do |moved|
        main = main_part(moved)
        next if main.size > LIMIT && moved < @commits.size - 1

        return [main, *earlier_parts(@commits.take(moved))].each { |part| check_size!(part) }
      end
    end

    private

    def main_part(moved)
      shown = @commits.drop(moved)
      blocks = [*header, commit_table(continuations(@commits.take(moved))), findings, *shown.map(&:to_s),
                @rounds.last.attestation]
      LocalReviewCommentPart.new(key, "#{blocks.join("\n\n")}\n", @rounds.last.attestation,
                                 [FINDINGS, *shown.flat_map(&:summaries)])
    end

    def header
      [TITLE, "**Reviewed revision:** #{@links.commit(@rounds.last.head)}", *@attention.visible,
       *@assessment_view.unavailable, coverage, usage_link, *fallback_notice, *settings_notice,
       *LocalReviewBound.new(@rounds, @max_rounds, budget: @task_budget).lines,
       *LocalReviewBudget.notice(@task_budget, completed: @rounds.size)]
    end

    # Which continuation holds each moved commit's reports, by head.
    def continuations(moved)
      earlier_groups(moved).each.with_index.with_object({}) do |(group, index), notes|
        group.each { |commit| notes[commit.head] = "reports in earlier comment #{index + 1}" }
      end
    end

    def earlier_parts(moved)
      earlier_groups(moved).each_with_index.map { |group, index| earlier_part(group, index + 1) }
    end

    # Packs the oldest commits into as few continuation comments as the limit allows, in ledger order.
    def earlier_groups(moved)
      moved.each_with_object([]) do |commit, groups|
        if groups.empty? || earlier_part(groups.last + [commit], groups.size).size > LIMIT - ARCHIVE_ROOM
          groups << [commit]
        else
          groups.last << commit
        end
      end
    end

    def earlier_part(group, number)
      attestation = @rounds.reverse.find { |round| round.head == group.last.head }.attestation
      blocks = ["#{TITLE} · earlier commits (#{number})",
                'Reports for earlier reviewed commits. The current outcome and findings are in the main ' \
                'Local Adversarial Review comment.',
                *group.map(&:to_s), attestation]
      LocalReviewCommentPart.new("#{key}-#{number}", "#{blocks.join("\n\n")}\n", attestation,
                                 group.flat_map(&:summaries))
    end

    def check_size!(part)
      return if part.size <= (part.key == key ? LIMIT : LIMIT - ARCHIVE_ROOM)

      raise Error, "Review comment #{part.key} exceeds GitHub’s 65536-character limit even with one commit's " \
                   'reports; shorten its reports.'
    end

    def commit_table(notes)
      rows = @rounds.chunk(&:head).map do |head, rounds|
        findings = rounds.map { |round| "#{round.reviewer}: #{round.finding_count}" }.join(' · ')
        findings += " · #{notes[head]}" if notes[head]
        line([@links.commit(head), findings])
      end
      ['**Reviewed commits:**', [line(%w[Commit Findings]), line(%w[--- ---]), *rows].join("\n")].join("\n\n")
    end

    def findings
      ["<details>\n<summary>#{FINDINGS}</summary>", *@attention.details, *@assessment_view.details,
       *@assessment_view.triage_history, *@assessment_view.triage_attribution,
       '### Execution metadata', table, '</details>'].join("\n\n")
    end

    def coverage
      rounds = @rounds.select { |round| round.head == @rounds.last.head }
      groups = rounds.group_by { |round| round.value('coverage') || 'UNKNOWN; see evidence.' }
      "**Coverage:** #{groups.map { |text, grouped| "#{grouped.map(&:reviewer).join(', ')}: #{text}" }.join(' · ')}"
    end

    def usage_link
      return 'Usage and attribution: see the PR description.' unless @usage_url

      "[Usage and attribution](#{@usage_url}) in the PR description."
    end
  end
end
