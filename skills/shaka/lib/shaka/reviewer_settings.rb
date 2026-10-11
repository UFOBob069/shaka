# frozen_string_literal: true

module Shaka
  # Names Shaka already prices or has seen a reviewer CLI accept.
  # Known spelling is not evidence that an account can use a model.
  module ReviewerCatalog
    Entry = Data.define(:models, :efforts, :closed_effort)

    ENTRIES = {
      'deepseek/openrouter' => Entry.new(
        models: ['deepseek/deepseek-v4.1-flash'], efforts: %w[low high max], closed_effort: true
      ),
      'openai/codex' => Entry.new(
        models: %w[gpt-5.6-terra gpt-5.6-sol gpt-6-astra gpt-6-sol gpt-6-luna],
        efforts: %w[low medium high xhigh],
        closed_effort: false
      ),
      'anthropic/claude' => Entry.new(
        models: %w[claude-fable-5-1 claude-fable-5 claude-opus-5-5 claude-opus-5 claude-opus-4-8
                   claude-opus-4-7 claude-opus-4-6 claude-opus-4-5 claude-sonnet-5 claude-sonnet-4-6
                   claude-sonnet-4-5 claude-haiku-4-5],
        efforts: %w[low medium high xhigh max],
        closed_effort: true
      ),
      'xai/grok' => Entry.new(
        models: %w[grok-4.5 grok-4.6 grok-4.7],
        efforts: %w[low medium high],
        closed_effort: false
      )
    }.freeze

    def self.entry(identity) = ENTRIES[identity]
  end

  # Compares one configured reviewer model and effort with the catalog.
  class ReviewerSettings
    def self.refuse!(notices)
      blocking = notices.select { |notice| notice.fetch('severity') == 'failed' }
      return if blocking.empty?

      raise Error, blocking.map { |notice| notice.fetch('summary') }.join(' ')
    end

    def self.attach(result, model:, notices:, effort: nil)
      result = result.merge('requested_model' => model) if model
      result = result.merge('requested_effort' => effort) if effort
      notices&.any? ? result.merge('config_notices' => notices) : result
    end

    def self.notices(identity, model: nil, effort: nil)
      entry = ReviewerCatalog.entry(identity)
      return [] unless entry

      new(identity, entry, model, effort).notices
    end

    def initialize(identity, entry, model, effort)
      @identity = identity
      @entry = entry
      @model = present(model)
      @effort = present(effort)
    end

    def notices
      [model_notice, effort_notice].compact
    end

    private

    def present(value)
      text = value.to_s
      return if text.strip.empty? || text == 'UNKNOWN'

      text
    end

    def model_notice
      return if @model.nil? || @entry.models.include?(@model)

      suggestion = near_miss(@model, @entry.models)
      return typo('model', @model, suggestion) if suggestion

      summary = "#{@identity} model `#{@model}` is not a model Shaka knows."
      notice('degraded', summary, 'Confirm the spelling. The review still runs with this model.')
    end

    def effort_notice
      return if @effort.nil? || @entry.efforts.include?(@effort)

      suggestion = near_miss(@effort, @entry.efforts)
      return closed_effort(suggestion) if @entry.closed_effort
      return typo('effort', @effort, suggestion) if suggestion

      notice('degraded', "#{@identity} effort `#{@effort}` is not a level Shaka knows.",
             'Confirm the spelling. The reviewer CLI decides whether it accepts this level.')
    end

    def typo(kind, value, suggestion)
      notice('degraded', "#{@identity} #{kind} `#{value}` looks like a typo of `#{suggestion}`.",
             'Confirm the spelling. The review still runs with this value.')
    end

    def closed_effort(suggestion)
      listed = @entry.efforts.join(', ')
      summary = "#{@identity} effort `#{@effort}` is not one of #{listed}."
      summary = "#{@identity} effort `#{@effort}` looks like a typo of `#{suggestion}`. #{summary}" if suggestion
      notice('failed', summary, 'Use one of those levels. This reviewer rejects anything else.')
    end

    def near_miss(value, names)
      names.find { |name| one_edit?(value, name) }
    end

    # Same length and one letter substitution, or one adjacent swap. A digit change is a
    # different version, such as grok-4.8 beside grok-4.7, so it is not called a typo.
    def one_edit?(left, right)
      return false unless left.length == right.length

      indexes = left.chars.each_index.reject { |index| left[index] == right[index] }
      return letter_change?(left, right, indexes.first) if indexes.length == 1

      transposed?(left, right, indexes)
    end

    def letter_change?(left, right, index)
      letter?(left[index]) && letter?(right[index])
    end

    def letter?(char) = char.match?(/[A-Za-z]/)

    def transposed?(left, right, indexes)
      return false unless indexes.length == 2 && indexes[1] == indexes[0] + 1

      left[indexes[0]] == right[indexes[1]] && left[indexes[1]] == right[indexes[0]]
    end

    def notice(severity, summary, guidance)
      { 'severity' => severity, 'summary' => summary, 'guidance' => guidance }
    end
  end
end
