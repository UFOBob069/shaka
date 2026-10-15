# frozen_string_literal: true

require_relative '../evidence/public_settings'
require_relative 'text'

module Shaka
  # Renders every setting by operation, for settings a reader cannot look up in the repository.
  module SettingsTable
    SUMMARY = 'Setting values at validation, review, and merge'
    FOLDED = { 'UNKNOWN' => 'UNKNOWN in every column',
               'REDACTED' => 'Never published, so REDACTED in every column' }.freeze

    module_function

    # Where a result's settings came from. Only a trusted revision is known to be a commit in this repository,
    # so only it is linked; a local revision is shown short.
    def source(settings, repository)
      kind, revision = settings.values_at('source', 'source.revision')
      if kind == 'UNKNOWN'
        kind
      else
        "#{kind} at #{PublicationText.commit(revision,
                                             (repository if kind == 'trusted/team'))}"
      end
    end

    # A second disclosure keeps the long table out of the way of the lines above it.
    def disclosure(columns)
      recorded, unrecorded = columns.partition { |_title, settings| settings.values.uniq != ['UNKNOWN'] }
      parts = [*unrecorded_note(unrecorded), *table(recorded)]
      "<details>\n<summary>#{SUMMARY}</summary>\n\n#{parts.join("\n\n")}\n\n</details>"
    end

    # A column no snapshot filled is named above the table instead of repeating UNKNOWN down it.
    def unrecorded_note(columns)
      titles = columns.map { |title, _settings| "**#{title}**" }.join(', ')
      columns.empty? ? [] : ["Not shown, because every setting is UNKNOWN there: #{titles}"]
    end

    def table(columns)
      return [] if columns.empty?

      rows = rows(columns).group_by { |field, cells| fold(field, cells) }
      lines = [['Setting', *columns.map(&:first)], ['---'] * (columns.size + 1), *rows.fetch(nil, []).map(&:flatten)]
      [lines.map { |cells| "| #{cells.join(' | ')} |" }.join("\n"), *folded_notes(rows)]
    end

    def rows(columns)
      Evidence::PublicSettings::FIELDS.map { |field| [field, columns.map { |_title, settings| settings[field] }] }
    end

    def folded_notes(rows)
      FOLDED.filter_map { |cell, lead| "#{lead}: #{rows[cell].map(&:first).join(', ')}" if rows.key?(cell) }
    end

    # A row that says the same nothing in every shown column is named on one line instead:
    # UNKNOWN throughout, or REDACTED throughout for a value the allowlist never publishes.
    # Any other row stays, so a cell that differs from its neighbours is always visible.
    def fold(field, cells)
      return 'UNKNOWN' if cells.all?('UNKNOWN')

      'REDACTED' if Evidence::PublicSettings::REDACTED.include?(field) && cells.all?('REDACTED')
    end
  end
end
