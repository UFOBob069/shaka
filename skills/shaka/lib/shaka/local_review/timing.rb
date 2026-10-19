# frozen_string_literal: true

require_relative '../call_log'

module Shaka
  # Retains timing without changing completion or reviewer-fallback rules.
  module LocalReviewTiming
    def run
      @attempted = false
      @validated_timeout_seconds = nil
      result, timing = CallLog.measure { with_requested_model(outcome) }
      timing['timeout_seconds'] = @validated_timeout_seconds if @validated_timeout_seconds
      retain_attempt(keep_round(result.merge(timing)))
    ensure
      tag_call_log
      finish_ledger
    end

    private

    # Settings are final here: a checkpoint run has merged its trusted reviewer choices.
    def tag_call_log
      provider = @options[:reviewer].to_s.split('/').first
      CallLog.tag(head: @options[:head], repository: @options[:repository], provider:,
                  model: @options[:model], effort: @options[:effort])
    end

    # Timing covers setup, invocation and report validation, before local evidence retention.
    def keep_round(result)
      record_round(result)
    rescue Shaka::Error, SystemCallError, JSON::ParserError => e
      with_requested_model(setup_failure(e)).merge(result.slice('started_at', 'duration_ms', 'timeout_seconds'))
    end

    # A failed attempt never becomes a completed round. An unavailable ledger keeps timing
    # in the returned result and explicitly reports the retention gap without changing review status.
    def retain_attempt(result)
      return result unless @options[:ledger]

      @ledger ||= LocalReviewLedger.new(@options[:ledger], root:)
      @ledger.record_attempt!(result)
      result.merge('attempt_log' => @ledger.attempt_log, 'timing_retention' => 'retained')
    rescue Shaka::Error, SystemCallError, JSON::ParserError, ArgumentError, TypeError => e
      result.merge('timing_retention' => 'not_retained', 'timing_retention_reason' => e.message)
    end
  end
end
