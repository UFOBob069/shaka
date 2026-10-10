# frozen_string_literal: true

require_relative 'claude_usage'

module Shaka
  # Reads only the current publisher's allowlisted response metadata, never transcript prose.
  class ClaudePublisherSettings
    AGENT = 'Claude Code'
    MODEL_SUFFIX = ''
    NOTE = nil
    # The session does not record which service served the model, so the provider stays as supplied.
    FIELDS = %w[model effort].freeze
    TOKEN = /\A[A-Za-z0-9][A-Za-z0-9._:-]{0,79}\z/
    UNAVAILABLE = 'Claude Code current turn settings unavailable'

    def self.read(environment)
      file = ClaudeUsage.session_file(environment['CLAUDE_CODE_SESSION_ID'], environment:)
      return { 'reason' => 'Claude Code session unavailable or ambiguous' } unless file

      new.read(file)
    end

    def read(file)
      clear(UNAVAILABLE)
      File.foreach(file, encoding: 'UTF-8') { |line| consume(line) }
      @settings.merge('reason' => @reason)
    rescue SystemCallError, EncodingError
      { 'reason' => 'Claude Code session unreadable' }
    end

    private

    def consume(line)
      return clear('Claude Code session contains unreadable metadata') unless line.valid_encoding?

      record = JSON.parse(line)
      consume_record(record) if record.is_a?(Hash) && record['isSidechain'] == false
    rescue JSON::ParserError, EncodingError
      clear('Claude Code session contains unreadable metadata')
    end

    def consume_record(record)
      case record['type']
      when 'user' then prompt(record['promptId'])
      when 'assistant' then response(record)
      end
    end

    # Tool results repeat their prompt's ID, so only a new or missing ID starts a turn.
    def prompt(identity)
      return if identity.is_a?(String) && identity == @turn

      @turn = identity
      clear(UNAVAILABLE)
    end

    # The host writes its own notices as `<synthetic>` responses; no model served those.
    def response(record)
      message = record['message']
      return unless message.is_a?(Hash) && message['model'] != '<synthetic>'

      @settings = { 'model' => token(message['model']), 'effort' => token(record['effort']) }
      @reason = UNAVAILABLE
    end

    def clear(reason)
      @settings = {}
      @reason = reason
    end

    def token(value)
      value if value.is_a?(String) && value.match?(TOKEN) && value != 'UNKNOWN'
    end
  end
end
