# frozen_string_literal: true

require 'cgi'
require 'json'
require_relative 'assessments'
require_relative 'attention'
require_relative 'public_triage'

module Shaka
  # Later judgments affect attention, never the historical review attestation or merge policy.
  class LocalReviewAssessmentView
    def initialize(content, displayed_rounds: nil)
      @history = LocalReviewAssessments.new(content)
      @rounds = displayed_rounds || content.fetch('rounds')
    end

    def attention?(id) = @history.attention?(id)

    def summary(rounds, links, total)
      outcome = LocalReviewAttention.new(rounds, links, assessments: self).visible.first
      [total, outcome, *unavailable].join("\n\n")
    end

    def status(id)
      return 'Needs decision: conflicting assessments' if @history.conflict?(id)
      return 'Evidence unavailable: assessment reference' if @history.for_finding(id).any? do |entry|
        !@history.available?(entry)
      end

      'Later assessment needs attention'
    end

    def visible(id)
      @history.for_finding(id).map do |entry|
        values = visible_values(entry.data)
        "#{literal(entry.id)} #{literal(values)} — #{literal(entry.data.fetch('rationale'))}"
      end.join(' · ')
    end

    def details
      return [] if @history.entries.empty?

      ['### Later assessments', *@history.entries.map { |entry| detail(entry) }]
    end

    def unavailable
      @history.active.filter_map do |entry|
        next if @history.available?(entry)

        "**Assessment reference unavailable:** #{literal(entry.id)} refers to #{literal(entry.finding)}; " \
          'recover or correct its finding/recommendation mapping.'
      end
    end

    def triage_history
      blocks = @rounds.filter_map do |round|
        earlier = LocalReviewBundle.earlier_findings(round)
        next if earlier.empty?

        earlier_triage(round, LocalReviewPublicTriage.snapshots(earlier))
      end
      blocks.empty? ? [] : ['### Preserved triage', *blocks]
    end

    def triage_attribution
      lines = @rounds.flat_map do |round|
        round.fetch('findings', []).filter_map do |finding|
          next unless finding['by']

          actor_line(round, finding)
        end
      end
      lines.empty? ? [] : ['### Triage attribution', *lines]
    end

    private

    def visible_values(data)
      values = data.slice('problem', 'remedy', 'implementation', 'attention')
                   .map { |key, value| "#{key}: #{value}" }
      action = data['action']
      values << "action: #{action.fetch('taken')}" if action
      values << "action attribution: #{action['attribution']}" if action&.key?('attribution')
      values.join(', ')
    end

    def earlier_triage(round, earlier)
      "**Earlier triage · #{round.fetch('head')[0, 7]} · #{literal(round.fetch('reviewer'))}:**\n\n#{json(earlier)}"
    end

    def actor_line(round, finding)
      by = finding['by']
      LocalReviewAssessment.actor!(by) if by
      actor = by ? "#{by.fetch('name')} (#{by.fetch('role')})" : 'UNKNOWN'
      "- #{literal(finding.fetch('id'))} · #{literal(round.fetch('reviewer'))}: " \
        "triaged by #{literal(actor)} at #{literal(finding.fetch('recorded_at', 'UNKNOWN'))}"
    end

    def detail(entry)
      state = @history.active.include?(entry) ? 'current' : 'superseded'
      state += '; reference unavailable' unless @history.historically_available?(entry)
      # Literal JSON retains each original judgment, evidence link and time without treating it as Markdown.
      "**#{literal(entry.id)} · #{state}:**\n\n#{json(entry.data)}"
    end

    def json(value) = "<pre>#{CGI.escapeHTML(JSON.pretty_generate(value)).gsub('|', '&#124;')}</pre>"

    # Encode punctuation before GFM can treat it as links, images, or emphasis inside inline HTML.
    def literal(value)
      text = value.to_s.gsub(/[^\p{Alnum} ]/) { |character| "&##{character.ord};" }
      "<code>#{text}</code>"
    end
  end
end
