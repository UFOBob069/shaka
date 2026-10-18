# frozen_string_literal: true

require_relative '../error'
require_relative 'text'
require_relative 'links'
require_relative 'usage_details'
require_relative 'provenance'
require_relative 'provenance_history'
require_relative 'wip_details'
require_relative 'settings'
require_relative 'steps_besides_merging'
require_relative 'human_comments'
require_relative 'skills_used'
require_relative 'intent_verification'
require_relative 'quoted_markers'
require_relative '../publication_sections'

module Shaka
  # Renders the publication surfaces so headings, spacing, tables and details are Ruby's.
  class Publication
    # With the pull request being replaced, the provenance history carries forward from its body.
    def self.description(content, workflow_version = nil, pull = nil, settings = nil)
      new(content, description: true, workflow_version:, pull:, settings:)
        .render(%i[steps intent_verification sections table provenance skills_used details wip credit],
                lead: %i[lead]).tap { QuotedMarkers.refuse!(content) }
    end

    def self.comment(content) = new(content).render([])

    def self.walkthrough(content, repository = nil)
      "#{new(content).render(%i[sections table details], title: true)}\n" \
        "#{PublicationLinks.walkthrough_footer(content['head'], repository)}\n"
    end

    def initialize(content, description: false, workflow_version: nil, pull: nil, settings: nil)
      raise Error, 'Publication content must be an object.' unless content.is_a?(Hash)

      @content = content
      @description = description
      @workflow_version = workflow_version
      @pull = pull
      @settings = settings || PublicationSettings.new
    end

    # A description leads with the maintainer's decision, so lead parts come before the summary.
    # Only a description names its summary, because there the decision line stands above it.
    def render(parts, title: false, lead: [])
      blocks = [PublicationText.publisher_identity(@content)]
      blocks << '# Code Walkthrough' if title
      lead.each { |part| blocks.concat(send(part)) }
      summary = PublicationText.required(@content['summary'], 'summary')
      blocks << (@description ? "## Summary\n\n#{summary}" : summary)
      parts.each { |part| blocks.concat(send(part)) }
      "#{blocks.join("\n\n")}\n"
    end

    private

    # Only a description is rendered with its pull request, so only a description lists what people wrote.
    def sections = PublicationSections.render(@content, HumanComments.for(@content, @pull, @settings))

    def lead = PublicationLinks.lead(@content, @pull, PublicationSections.decisions(@content['decisions']))

    # The steps besides merging sit right under the summary so a reader cannot miss them.
    def steps = StepsBesidesMerging.render(@content)

    def credit = PublicationLinks.credit(@settings)

    # Intent and verification answer whether to trust the merge, so they come before any section.
    def intent_verification = IntentVerification.render(@content)

    # Verification carries the proof, so a table only adds facts that fit no check.
    def table
      spec = @content['table']
      return [] if spec.nil?

      columns = table_columns(spec)
      [[table_line(columns), table_line(['---'] * columns.size), *table_data_rows(spec, columns.size)].join("\n")]
    end

    def table_data_rows(spec, width)
      rows = PublicationText.list(spec['rows'], 'table rows')
      raise Error, 'Publication table must include at least one row.' if rows.empty?

      rows.map { |row| table_row(row, width) }
    end

    def table_columns(spec)
      columns = spec.is_a?(Hash) ? PublicationText.list(spec['columns'], 'table columns') : []
      raise Error, 'Publication table must define at least one column.' if columns.empty?

      columns.map { |column| PublicationText.single_line(column, 'table column') }
    end

    def table_row(row, width)
      cells = PublicationText.list(row, 'table row')
      raise Error, "Publication table row has #{cells.size} cells; #{width} columns are defined." if cells.size != width

      table_line(cells.map { |cell| PublicationText.single_line(cell.to_s, 'table cell') })
    end

    def table_line(cells) = "| #{cells.map { |cell| PublicationText.table_cell(cell) }.join(' | ')} |"

    def details
      items = PublicationText.list(@content['details'], 'details')
      validate_details(items) if @description
      items = [@settings.detail, *items] if @description
      rendered = items.map { |detail| details_block(detail) }
      rendered.unshift(details_block(UsageDetails.new(@content['usage']).detail)) if @description
      rendered
    end

    def validate_details(items)
      UsageDetails.refuse_free_form!(items)
      refuse_free_form_wip(items)
      refuse_supplied_history(items)
      [PublicationSettings, SkillsUsed].each { |validator| validator.refuse_free_form!(items) }
    end

    # The note is optional because it disappears once GitHub confirms the outcome.
    def wip
      spec = @content['wip']
      spec.nil? ? [] : [details_block(WipDetails.new(spec, path_redaction: @settings.path_redaction).detail)]
    end

    def refuse_free_form_wip(items)
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.casecmp?(WipDetails::SUMMARY) }

      raise Error, 'Publication WIP Details must be supplied as the wip object, not a details item.'
    end

    # Only the helper writes the history, from the previous body.
    def refuse_supplied_history(items)
      summary = ProvenanceHistory::SUMMARY
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.casecmp?(summary) }

      raise Error, 'Publication provenance history is carried from the PR body, not supplied as a details item.'
    end

    def provenance
      spec = @content.fetch('provenance') do
        raise Error, 'Publication description requires execution provenance.'
      end
      execution = ExecutionProvenance.new(spec, workflow_version: @workflow_version)
      return [details_block(execution.detail)] unless @pull

      history = ProvenanceHistory.carry(@pull, execution.entry)
      detail = execution.detail
      marked = detail.merge('body' => "#{detail['body']}\n\n#{ProvenanceHistory.marker(history)}")
      [details_block(marked), *ProvenanceHistory.detail(history)&.then { |item| details_block(item) }]
    end

    def skills_used = [details_block(SkillsUsed.new(@content['skills_used']).detail)]

    def details_block(detail)
      summary = PublicationText.summary_text(detail['summary'], 'details summary')
      body = PublicationText.required(detail['body'], "details #{summary}")
      "<details>\n<summary>#{summary}</summary>\n\n#{body}\n\n</details>"
    end
  end
end
