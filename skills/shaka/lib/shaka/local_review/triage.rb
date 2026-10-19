# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Renders how the reviews of one commit were collated: which of each reviewer's own findings
  # became which finding, then what became of each finding, once.
  class LocalReviewTriage
    def self.line(finding, links, fixed_before)
      result = finding.fixed? ? "fixed in #{links.commit(finding.commit)}" : finding.label
      line = "- `#{finding.id}` #{finding.kind}: #{finding.summary} — #{result}"
      line += " — #{finding.note}" if finding.note
      line += " — Decision: #{finding.decision}" if finding.decision
      returned = fixed_before[finding.id]
      returned ? "#{line} · **returned after its fix in #{links.commit(returned)}**" : line
    end

    # The rounds of one commit share one triage, so a finding they share has one outcome. A ledger
    # always records it that way; a hand-written content file might not.
    def self.check!(rounds)
      rounds.chunk(&:batch).each do |(head, _settings), batch|
        split = batch.flat_map(&:findings).group_by(&:id).find { |_, copies| outcomes(copies) > 1 }
        raise Error, "Finding #{split.first} has two outcomes in the reviews of #{head[0, 7]}." if split
      end
    end

    def self.outcomes(copies)
      copies.map { |item| [item.kind, item.disposition, item.commit, item.decision] }.uniq.size
    end

    # Every commit's triage, in order and before the reports, so a reader sees what each reviewer
    # reported, how the findings were collated, and what became of each without opening a report.
    def self.section(rounds, links)
      fixed = {}
      blocks = rounds.chunk(&:batch).map do |(head, _settings), batch|
        text = new(head, batch, links).render(fixed)
        remember_fixes(batch, fixed)
        text
      end
      ['## Findings', *blocks]
    end

    # Records each fix a commit's triage made, so a later commit flags a finding that returned.
    def self.remember_fixes(batch, fixed)
      batch.flat_map(&:findings).select(&:fixed?).each { |finding| fixed[finding.id] = finding.commit }
    end

    # A commit's reports. Under a report of a commit several reviewers read, which of its findings
    # became which finding. Dispositions live in the generated findings view, never in the reports.
    def self.details(batch) = batch.map { |round| round.details(collated: !batch.one?) }

    # Under one reviewer's collapsed report: its own findings and the finding each became.
    def self.collated_as(round)
      return '' if round.findings.empty?

      pairs = round.findings.map { |finding| "`##{finding.reported_as || '?'}` → `#{finding.id}`" }
      "**Collated as:** #{pairs.join(', ')}\n\n"
    end

    def initialize(head, batch, links)
      @head = head
      @batch = batch
      @links = links
    end

    def render(fixed_before)
      findings = @batch.flat_map(&:findings).uniq(&:id)
      title = "**Triage of #{@links.commit(@head)}**#{@batch.first.label} · #{counts}"
      return title if findings.empty?

      lines = findings.map do |finding|
        found = reporters(finding.id)
        "#{self.class.line(finding, @links, fixed_before)} — #{found.size == 1 ? 'reporter' : 'reporters'}: " \
          "#{found.join(', ')}"
      end
      "#{title}\n\n#{lines.join("\n")}"
    end

    private

    # Every reviewer of the commit and how many findings it reported, including none.
    def counts
      @batch.map do |round|
        size = round.findings.size
        "#{round.reviewer}: #{size} #{size == 1 ? 'finding' : 'findings'}"
      end.join(' · ')
    end

    # A reviewer's own number stays in code, where GitHub does not read `#1` as issue 1.
    def reporters(id)
      @batch.filter_map do |round|
        finding = round.findings.find { |item| item.id == id }
        next unless finding

        finding.reported_as ? "#{round.reviewer} `##{finding.reported_as}`" : round.reviewer
      end
    end
  end
end
