# frozen_string_literal: true

require_relative 'summary'
require_relative '../repository_config/review_schema'

module Shaka
  # Shows non-convergence outside the collapsed reports and supplies a maintainer's next prompt.
  class LocalReviewBound
    def initialize(rounds, max_rounds, budget: nil)
      @rounds = rounds
      @max_rounds = max_rounds
      @budget = budget
    end

    def lines
      unresolved = LocalReviewSummary.new(@rounds).unresolved_defects
      return [] unless exhausted? && !unresolved.empty?

      ['## Loop bound reached', "Local review reached the #{cap} with unresolved defects:",
       unresolved.map { |finding| defect_line(finding) }.join("\n"), prompt(unresolved)]
    end

    private

    def exhausted?
      @budget ? @budget.fetch('used') >= @budget.fetch('limit') : @rounds.map(&:head).uniq.size >= @max_rounds
    end

    def cap_name = @budget ? 'task execution budget' : 'round cap'

    def cap = "#{cap_name} (#{@budget ? @budget.fetch('limit') : @max_rounds})"

    def defect_line(finding)
      appearances = appearances(finding.id)
      numbers = appearances.map { |_, index| index + 1 }.join(', ')
      line = "- `#{finding.id}`: #{finding.summary} — rounds #{numbers}"
      returned?(appearances, finding.id) ? "#{line} · **returned after being marked fixed**" : line
    end

    def appearances(id)
      @rounds.each_with_index.select { |round, _| round.findings.any? { |item| item.id == id } }
    end

    def returned?(appearances, id)
      appearances[0...-1].any? do |round, _|
        round.findings.any? { |item| item.id == id && item.fixed? }
      end
    end

    def prompt(unresolved)
      defects = unresolved.map { |finding| "#{finding.id}: #{finding.summary}" }.join('; ')
      "**Ready task-reassessment prompt:**\n\n" \
        "> Local review hit the #{cap_name} on this task with these unresolved defects: #{defects}. " \
        'Reassess the task: is a requirement contradictory, is the scope too large for one PR, or is a ' \
        'constraint impossible? Propose a revised task definition or split.'
    end
  end
end
