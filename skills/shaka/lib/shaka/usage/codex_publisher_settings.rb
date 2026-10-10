# frozen_string_literal: true

require_relative 'codex_usage'

module Shaka
  # Reads only the current publisher's allowlisted native configuration, never transcript prose.
  class CodexPublisherSettings
    AGENT = 'Codex'
    MODEL_SUFFIX = ' (configured)'
    NOTE = 'Publisher model is configured; served model is UNKNOWN.'
    FIELDS = %w[provider model effort].freeze
    TOKEN = /\A[A-Za-z0-9][A-Za-z0-9._:-]{0,79}\z/

    def self.read(environment)
      file = CodexUsage.session_file(environment['CODEX_THREAD_ID'], environment:)
      return { 'reason' => 'Codex session unavailable or ambiguous' } unless file

      new.read(file)
    end

    def read(file)
      @settings = {}
      @reason = 'Codex current turn settings unavailable'
      File.foreach(file, encoding: 'UTF-8') { |line| consume(line) }
      @settings.merge('reason' => @reason)
    rescue SystemCallError, EncodingError
      { 'reason' => 'Codex session unreadable' }
    end

    private

    def consume(line)
      return invalidate unless line.valid_encoding?

      record = JSON.parse(line)
      return invalidate unless record.is_a?(Hash) && record['payload'].is_a?(Hash)

      consume_record(record['type'], record['payload'])
    rescue JSON::ParserError, EncodingError
      invalidate
    end

    def consume_record(type, payload)
      case type
      when 'session_meta' then @provider = token(payload['model_provider'])
      when 'turn_context' then context(payload)
      when 'event_msg' then event(payload)
      end
    end

    def event(payload)
      return unless %w[task_started task_complete].include?(payload['type'])

      @turn = payload['turn_id']
      @settings = {}
      @reason = 'Codex current turn settings unavailable'
    end

    def context(payload)
      @settings = if current_turn?(payload['turn_id'])
                    { 'agent' => 'Codex', 'provider' => @provider,
                      'model' => token(payload['model']), 'effort' => token(payload['effort']) }
                  else
                    {}
                  end
      @reason = 'Codex current turn settings unavailable'
    end

    def current_turn?(turn)
      turn.is_a?(String) && !turn.empty? && (!@turn || turn == @turn)
    end

    def invalidate
      @provider = nil
      @settings = {}
      @reason = 'Codex session contains unreadable metadata'
    end

    def token(value)
      value if value.is_a?(String) && value.match?(TOKEN) && value != 'UNKNOWN'
    end
  end
end
