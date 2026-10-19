# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative '../post_implementation_report'
require_relative '../publication/intent_verification'

module Shaka
  # The checkpoint reads the description content, so it judges exactly what the maintainer reads.
  module PostImplementationPacket
    # Only these are the checkpoint's own; the description already states the problem, scope, and proof.
    OWN = %w[audience repair_history].freeze
    WRITTEN_TWICE = %w[problem outcome validation].freeze

    module_function

    def read(path)
      raise Error, 'Checkpoint content exceeds 100 KB' if File.size(path) > 100_000

      content = JSON.parse(File.read(path, encoding: 'UTF-8'))
      raise Error, 'Checkpoint content must be the description content object' unless content.is_a?(Hash)

      build(content)
    rescue JSON::ParserError => e
      raise Error, "Malformed checkpoint content: #{e.message}"
    end

    def build(content)
      stale = content.keys & WRITTEN_TWICE
      raise Error, "Checkpoint content states #{stale.join(', ')} in intent and verification instead" if stale.any?

      IntentVerification.render(content.except('wip'))
      raise Error, 'Checkpoint content needs a non-empty summary' unless text?(content['summary'])

      own = own(content['checkpoint'])
      content.slice('summary', 'intent', 'verification').merge(own.slice(*OWN, 'evidence'))
    end

    # An optional evidence list carries what the description has no place for, such as instruction growth.
    def own(checkpoint)
      raise Error, "Checkpoint content needs checkpoint #{OWN.join(' and ')} as non-empty strings" unless
        checkpoint.is_a?(Hash) && OWN.all? { |key| text?(checkpoint[key]) }

      evidence = checkpoint.fetch('evidence', [])
      raise Error, 'Checkpoint evidence must be a list of non-empty strings' unless
        evidence.is_a?(Array) && evidence.all? { |entry| text?(entry) }

      checkpoint
    end

    def text?(value) = PostImplementationReport.text?(value)
  end
end
