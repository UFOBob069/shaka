# frozen_string_literal: true

module Shaka
  # A response that consulted the advisor tool lists its sub-inferences in `usage.iterations`.
  # The top-level counters cover only the executor's `message` iterations; each
  # `advisor_message` iteration is billed separately at the advisor model's rates.
  module ClaudeIterations
    private

    # One response per advisor sub-inference, keyed by its position so streamed copies count once.
    # Without the executor's identity there is nothing to key them by, so they stay uncounted with it.
    def advisor_responses(identity, usage, base)
      return {} unless identity.is_a?(String) && !identity.empty?

      advisors = iterations(usage).select { |item| item.is_a?(Hash) && item['type'] == 'advisor_message' }
      advisors.each_with_index.to_h do |iteration, index|
        key = "#{identity}/advisor/#{index}"
        [key, base.merge('response_id' => key, 'configuration' => ['anthropic', 'UNKNOWN', iteration['model'], nil],
                         'billing_mode' => advisor_speed(usage),
                         'usage' => tokens(iteration).merge('inference_geo' => usage['inference_geo']))]
      end
    end

    # Fast mode is requested for the executor; only a standard request establishes the advisor's rate.
    def advisor_speed(usage) = speed(usage) == 'standard' ? 'standard' : 'UNKNOWN'

    # The top-level TTL split holds only the first executor iteration, so the split is
    # rebuilt from every `message` iteration to match the cache-write total. When the
    # iterations cannot establish it, the recorded split stands for the estimate to check.
    def executor_write_split(usage)
      messages = iterations(usage).select { |iteration| !iteration.is_a?(Hash) || iteration['type'] == 'message' }
      split = %w[ephemeral_5m_input_tokens ephemeral_1h_input_tokens].map { |field| writes(messages, field) }
      split if messages.any? && split.all?(Integer)
    end

    def writes(messages, field)
      counts = messages.map { |iteration| iteration_writes(iteration, field) }
      counts.sum if counts.all?(Integer)
    end

    # An iteration that wrote nothing to the cache needs no split to establish both TTL counts.
    def iteration_writes(iteration, field)
      return unless iteration.is_a?(Hash)
      return 0 if iteration['cache_creation_input_tokens'].eql?(0) && !iteration['cache_creation'].is_a?(Hash)

      nested(iteration, 'cache_creation', field)
    end

    def iterations(usage)
      recorded = usage['iterations'] if usage.is_a?(Hash)
      recorded.is_a?(Array) ? recorded : []
    end
  end
end
