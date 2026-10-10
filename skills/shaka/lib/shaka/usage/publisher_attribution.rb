# frozen_string_literal: true

require_relative '../error'
require_relative 'claude_publisher_settings'
require_relative 'codex_publisher_settings'

module Shaka
  # Resolves publisher fields once for the header and active provenance. Reviewers stay separate.
  module PublisherAttribution
    HOST_VARIABLES = %w[CODEX_THREAD_ID CLAUDE_CODE_SESSION_ID CURSOR_CONVERSATION_ID
                        OPENCODE_SESSION_ID PI_CODING_AGENT].freeze
    READERS = { 'CODEX_THREAD_ID' => CodexPublisherSettings,
                'CLAUDE_CODE_SESSION_ID' => ClaudePublisherSettings }.freeze

    def self.prepare(content, environment: ENV)
      hosts = HOST_VARIABLES.select { |variable| present?(environment, variable) }
      reader = READERS[hosts.first] if hosts.one?
      unless reader
        return content.merge('publisher_note' => 'Native publisher settings unavailable for this host; ' \
                                                 'supplied attribution is unverified.')
      end

      apply(content, reader, reader.read(environment))
    end

    def self.present?(environment, variable)
      variable == 'PI_CODING_AGENT' ? environment[variable] == 'true' : !environment[variable].to_s.empty?
    end

    def self.apply(content, reader, observed)
      result = content.merge('identity' => identity(content['identity'], reader, observed),
                             'publisher_note' => note(reader, observed))
      return result unless content['provenance'].is_a?(Hash)

      provenance = content['provenance'].merge(%w[model effort].to_h do |field|
        key = "active_#{field}"
        [key, resolve(content['provenance'][key], observed[field], key)]
      end)
      result.merge('provenance' => provenance)
    end

    def self.identity(supplied, reader, observed)
      supplied ||= {}
      raise Error, 'Native publisher attribution requires an identity object.' unless supplied.is_a?(Hash)

      resolved = supplied.slice('provider').merge((['agent'] + reader::FIELDS).to_h do |field|
        [field, resolve(supplied[field], observed[field], field)]
      end)
      resolved['model'] += reader::MODEL_SUFFIX unless resolved['model'] == 'UNKNOWN'
      resolved.merge('agent' => reader::AGENT)
    end

    def self.resolve(supplied, actual, field)
      check(supplied, actual, field)
      actual || 'UNKNOWN'
    end

    def self.check(supplied, actual, field)
      return unless actual && supplied.is_a?(String) && !supplied.empty? && supplied != 'UNKNOWN'
      return if supplied.delete_suffix(' (configured)').downcase == actual.downcase

      raise Error, "Publication #{field} conflicts with native publisher settings."
    end

    def self.note(reader, observed)
      missing = reader::FIELDS.reject { |field| observed[field] }
      gap = "UNKNOWN #{missing.join(', ')}: #{observed.fetch('reason')}." unless missing.empty?
      note = [reader::NOTE, gap].compact.join(' ')
      note unless note.empty?
    end

    private_class_method :present?, :apply, :identity, :resolve, :check, :note
  end
end
