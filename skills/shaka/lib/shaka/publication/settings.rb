# frozen_string_literal: true

require_relative '../evidence/verification'
require_relative '../evidence/public_settings'
require_relative 'feature_guard'
require_relative '../opening_publication'
require_relative 'settings_table'

module Shaka
  # Consumes existing results; never stores a second receipt or rewrites an earlier one.
  class PublicationSettings
    SUMMARY = 'Shaka settings used'
    MISSING_REF = 'Withheld: settings not read; rerun description with --ref'
    UNAVAILABLE_SETTINGS = 'Withheld: settings unavailable; fix seam check --ref, then rerun description'

    def self.refuse_free_form!(items)
      return unless items.any? do |item|
        item.is_a?(Hash) && item['summary'].to_s.strip.casecmp?(SUMMARY)
      end

      raise Error, 'Shaka settings must come from validation/review results, not a details item.'
    end

    def self.prepare(root:, ref:, pull:, options:, github:)
      FeaturePublication.check(github:, pull:, flow: options.fetch(:publication_flow, 'feature'))
      repository = github.repository
      verdict = verify(root:, ref:, repository:, pull:, options:)
      current = current_settings(root:, ref:, repository:, required: !verdict.nil?) if ref
      new(verdict:, current:, location_diagnostic: ref ? UNAVAILABLE_SETTINGS : MISSING_REF)
    end

    def self.verify(root:, ref:, repository:, pull:, options:)
      paths = { validation: options[:validation], review: options[:review] }
      return unless paths.values.any?
      raise Error, 'Settings publication requires --ref and --root' unless ref && options[:root]

      verdict = Evidence::Verification.new(root:, ref:, repository:, head: pull.dig('head', 'sha'), paths:).run
      raise Error, 'Settings evidence is missing or stale; rerun affected validation/review' unless
        verdict['status'] == 'ready'

      verdict
    end

    def self.current_settings(root:, ref:, repository:, required: false)
      OpeningPublication.with_safe_path(root:, select_gh: false) do |candidate_root|
        _config, _settings, _kind, current = Evidence::Inputs.capture(root: candidate_root, ref:, repository:)
        current
      end
    rescue Error, SystemCallError
      raise if required

      nil
    end

    def initialize(verdict: nil, current: nil, location_diagnostic: MISSING_REF)
      @verdict = verdict
      @current = current
      @location_diagnostic = location_diagnostic
    end

    # An unknown policy cannot authorize publishing locations, even on unfinished PRs.
    def include_locations? = @current&.fetch('wip.include_locations', false) == true

    def location_redaction
      return if include_locations?
      return 'REDACTED' if @current&.fetch('wip.include_locations', nil) == false

      @location_diagnostic
    end

    # Only resolved settings can establish whether the repository opted out.
    def attribution? = @current&.fetch('pr_description.show_shaka_credit', false) == true

    NOTE = 'Local files remain local. This reports operation settings and cannot restore them. ' \
           'It does not prove earlier checks ran. Private merge.preference grants no Auto authority. ' \
           'Private trials default to Ask; explicit user authorization and live required gates govern merging.'
    OPERATIONS = { 'validation' => 'Before push: validation', 'review' => 'Review' }.freeze
    CURRENT = 'Current merge input (not evidence)'
    # Settings from these sources are not readable in the repository, so the block keeps every value.
    UNCOMMITTED = %w[private/local preview/local].freeze

    def detail
      status = @verdict ? 'Bound to the current candidate commit.' : 'UNKNOWN: rerun missing evidence.'
      { 'summary' => SUMMARY, 'body' => [status, NOTE, current_line, *operations_table, *values].join("\n\n") }
    end

    private

    def current_line
      settings = Evidence::PublicSettings.sanitize(@current)
      version, installation = settings.values_at('installation.version', 'installation.source')
      shaka = installation == 'UNKNOWN' ? version : "#{version} (installation: #{installation})"
      "#{CURRENT}: #{source(settings)}; Shaka #{shaka}"
    end

    # One row per recorded result. Binding refuses a result whose settings differ from the
    # current ones, so a row needs only what can still vary: its revision and what it ran with.
    def operations_table
      rows = operations.map { |title, settings| [title, source(settings), ran_with(settings)] }
      return [] if rows.empty?

      lines = [['Operation', 'Settings', 'Ran with'], %w[--- --- ---], *rows]
      [lines.map { |cells| "| #{cells.join(' | ')} |" }.join("\n")]
    end

    def operations
      OPERATIONS.flat_map do |kind, title|
        Array(@verdict&.dig('checks', kind)).map do |entry|
          [title, Evidence::PublicSettings.sanitize(entry.dig('original', 'public_settings'))]
        end
      end
    end

    def source(settings)
      kind, revision = settings.values_at('source', 'source.revision')
      kind == 'UNKNOWN' ? kind : "#{kind} at #{revision}"
    end

    def ran_with(settings)
      command, reviewer, effort = settings.values_at('overrides.command', 'overrides.reviewer', 'overrides.effort')
      parts = [command, reviewer, ("#{effort} effort" unless effort == 'UNKNOWN')].compact - ['UNKNOWN']
      parts.empty? ? 'UNKNOWN' : parts.join(', ')
    end

    def values
      columns = operations.map { |title, settings| [column_title(title, settings), settings] }
      columns << [CURRENT, Evidence::PublicSettings.sanitize(@current)]
      return [] unless columns.any? { |_title, settings| UNCOMMITTED.include?(settings['source']) }

      [SettingsTable.disclosure(columns)]
    end

    # Several reviewers would otherwise share one column title.
    def column_title(title, settings)
      reviewer = settings['overrides.reviewer']
      reviewer == 'UNKNOWN' ? title : "#{title}: #{reviewer}"
    end
  end
end
