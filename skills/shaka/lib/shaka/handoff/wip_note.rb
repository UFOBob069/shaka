# frozen_string_literal: true

require_relative '../publication/publishing'
require_relative '../publication/wip_details'

module Shaka
  class Handoff
    # Reads back the WIP Details note that `description` published, from the description's managed region.
    module WipNote
      NOTE = %r{<details>\n<summary>#{WipDetails::SUMMARY}</summary>\n\n(.*?)\n\n</details>}m
      ROW = /\A\| (.+?) \| (.*) \|\z/

      module_function

      # The Revision cell of a complete note, or nil when the body holds none.
      def revision(body)
        value(body, 'revision')
      end

      def value(body, field)
        # A body saved from GitHub's web editor comes back with CRLF line endings.
        region = Publishing.managed_region(body.to_s.gsub("\r\n", "\n")).to_s
        note = region[NOTE, 1] or return
        cell = cells(note)&.fetch(WipDetails::FIELDS.keys.index(field))
        PublicationText.table_cell_text(cell) unless cell.to_s.strip.empty?
      end

      # The Value column in field order, or nil for a partial or reordered table WipDetails did not render.
      def cells(note)
        rows = note.lines.drop(2).map { |line| line.chomp.match(ROW)&.captures || [] }
        rows.map(&:last) if WipDetails::RECOGNIZED_HEADINGS.include?(rows.map(&:first))
      end

      # Revision reads `BRANCH @ SHA`; only the part after the last ` @ ` is the head, whatever the branch is named.
      def head(revision) = revision.to_s.split(' @ ').last.to_s.strip
    end
  end
end
