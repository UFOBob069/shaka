# frozen_string_literal: true

require_relative 'usage'

module Shaka
  # Links a commit to GitHub only when GitHub has it. A round reviewed before a rebase names a
  # commit that was never pushed, and a link to it would open a 404 page; `rebased` names the
  # pushed copy of such a commit, if one is known, and the reviewed commit links there instead.
  class LocalReviewLinks
    def initialize(repository, published = nil, rebased = nil)
      @repository = repository
      @published = published
      @rebased = rebased
      @known = {}
    end

    # Code spans are never auto-linked, so a commit needs an explicit link to be clickable.
    def commit(sha)
      code = "`#{sha[0, 7]}`"
      return code unless @repository
      return link(code, sha) if on_github?(sha)

      copy = @rebased&.call(sha)
      copy ? "#{code}, rebased as #{link("`#{copy[0, 7]}`", copy)}" : "#{code} (not on GitHub)"
    end

    def criteria(sha)
      code = "`#{sha[0, 7]}`"
      # The criteria can come from nested AGENTS.md files alone, so the link opens the commit's tree.
      @repository ? "[#{code}](https://github.com/#{@repository}/tree/#{sha})" : code
    end

    private

    def link(code, sha) = "[#{code}](https://github.com/#{@repository}/commit/#{sha})"

    def on_github?(sha)
      return true unless @published

      @known.fetch(sha) { @known[sha] = @published.call(sha) }
    end
  end

  # The lines under the summary table: what the loop cost, why it stopped, and what the prompt
  # line means.
  class LocalReviewSummary
    INSTRUCTIONS = 'https://github.com/shakacode/shaka/blob/main/skills/shaka/config/review-prompt.md'
    RULES = 'https://github.com/shakacode/shaka/blob/main/skills/shaka/lib/shaka/review_prompt.rb'
    NUMBER = /\A\d{1,3}(?:,\d{3})*\z|\A\d+\z/
    # `shaka usage` marks an estimate that leaves some responses unpriced as `(partial)`.
    MONEY = /\A\$?(\d+(?:\.\d+)?)( \(partial\))?\z/

    # Each distinct prompt once, with its rounds named only when the rounds used different prompts.
    def self.prompts(rounds, links)
      groups = rounds.group_by { |round| round.prompt(links) }
      return "**Prompt:** #{groups.keys.first}" if groups.one?

      texts = groups.map do |text, grouped|
        "#{text} (#{grouped.one? ? 'round' : 'rounds'} #{grouped.map(&:number).join(', ')})"
      end
      "**Prompt:** #{texts.join('; ')}"
    end

    def initialize(rounds) = @rounds = rounds

    def lines = [total, outcome, prompt]

    # A later reclassification or omission does not erase a previously reported defect.
    def unresolved_defects
      findings = @rounds.flat_map(&:findings)
      ids = findings.select { |finding| finding.kind == 'defect' }.map(&:id).uniq
      latest = findings.to_h { |finding| [finding.id, finding] }
      ids.map { |id| latest.fetch(id) }.reject(&:closed?)
    end

    private

    def total
      "**Total:** #{@rounds.size} #{@rounds.size == 1 ? 'round' : 'rounds'} · #{tokens} · #{cost}"
    end

    def tokens
      return 'token categories per round (totals not combined)' if @rounds.any?(&:usage_record)

      counts = @rounds.map { |round| round.value('tokens').to_s }
      return 'tokens UNKNOWN' unless counts.all? { |count| count.match?(NUMBER) }

      "#{group(counts.sum { |count| count.delete(',').to_i })} tokens"
    end

    # A subscription session has no per-token bill, so its dollar figure is an API-equivalent estimate.
    def cost
      return captured_cost if @rounds.any?(&:usage_record)

      prices = @rounds.map { |round| price(round).match(MONEY) }
      return 'cost UNKNOWN' if prices.any?(&:nil?)

      format('$%<sum>.2f %<label>s', sum: prices.sum { |match| match[1].to_f }, label: cost_label(prices))
    end

    def captured_cost
      columns = @rounds.flat_map do |round|
        round.usage_record ? round.usage_record.fetch('columns') : [{ 'usd' => price(round) }]
      end
      LocalReviewUsage.cost('columns' => columns)
    end

    def cost_label(prices)
      label = @rounds.all? { |round| round.value('cost') } ? 'cost' : 'API-equivalent estimate'
      prices.any? { |match| match[2] } ? "#{label} (partial)" : label
    end

    def price(round) = (round.value('cost') || round.value('estimate')).to_s

    # Older open or unassessed findings survive a clean latest round until explicitly closed.
    def outcome
      pending = @rounds.flat_map(&:findings).group_by(&:id).values
                       .select { |copies| LocalReviewFinding.pending?(copies) }.map(&:last)
      return '**Outcome:** No open findings; closed and optional findings are in history.' if pending.empty?

      "**Outcome:** #{pending.size} #{pending.size == 1 ? 'finding needs' : 'findings need'} attention " \
        "(#{kinds(pending)})."
    end

    def kinds(findings)
      LocalReviewFinding::CLASSES.filter_map do |kind|
        count = findings.count { |finding| finding.kind == kind }
        "#{count} #{kind}" if count.positive?
      end.join(', ')
    end

    def prompt
      "**Prompt sources:** `Shaka default` is Shaka's [review instructions](#{INSTRUCTIONS}) plus its " \
        "[fixed rules](#{RULES}); a `review.prompt_file` entry names the repository file used instead. " \
        '`criteria SHA` means the reviewer also received the trusted `AGENTS.md` files from that commit.'
    end

    def group(number) = number.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
  end
end
