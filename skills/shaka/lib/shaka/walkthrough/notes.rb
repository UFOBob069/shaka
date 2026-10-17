# frozen_string_literal: true

require_relative '../error'
require_relative '../publication/text'
require_relative 'code_links'

module Shaka
  module Walkthrough
    # Turns walkthrough `notes` into the inline comments of the walkthrough review: guidance
    # for the reviewer on the lines it is about. A note finds its lines by text at the head, as
    # a code link does. Its body opens with a marker, so comment readers treat it as an agent
    # post, followed by the publisher identity.
    module Notes
      MARKER = '<!-- shaka:walkthrough-note -->'
      FIELDS = %w[path from to block body].freeze

      module_function

      def resolve(content, github)
        notes = content.fetch('notes', [])
        raise Error, 'Walkthrough notes must be a list.' unless notes.is_a?(Array)
        return [] if notes.empty?

        locator = CodeLinks.new({}, github, content.fetch('head'))
        identity = PublicationText.identity(content['identity'])
        notes.each.with_index(1).map { |note, number| comment(note, number, locator, identity) }
      end

      def comment(note, number, locator, identity)
        label = "note #{number}"
        raise Error, "Walkthrough #{label} must be an object." unless note.is_a?(Hash)

        unknown = note.keys - FIELDS
        raise Error, "Walkthrough #{label} has unknown key #{unknown.first}." unless unknown.empty?

        body = PublicationText.required(note['body'], "walkthrough #{label}")
        first, last = locator.locate(label, note)
        anchor(note['path'], first, last).merge('body' => "#{MARKER}\n#{identity}\n\n#{body.strip}")
      end

      # GitHub anchors a comment on its last line and, for a range, also its first.
      def anchor(path, first, last)
        anchor = { 'path' => path, 'line' => last, 'side' => 'RIGHT' }
        first < last ? anchor.merge('start_line' => first, 'start_side' => 'RIGHT') : anchor
      end

      def location(note)
        lines = note['start_line'] ? "L#{note['start_line']}-L#{note['line']}" : "L#{note['line']}"
        "#{note['path']}:#{lines}"
      end
    end
  end
end
