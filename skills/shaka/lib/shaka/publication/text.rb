# frozen_string_literal: true

require_relative '../error'

module Shaka
  # Checks supplied text for the mechanical failures models reproduce by hand.
  module PublicationText
    ESCAPE = /\\[nrt]/
    IDENTITY_FIELDS = %w[agent provider model effort].freeze

    # A cell's code spans, unclosed backtick runs, and the text between them.
    CELL_PARTS = /(?<!`)(`+)(?!`).+?(?<!`)\1(?!`)|`+|[^`]+/m

    DISPLAY_NAMES = {
      'agent' => { 'codex' => 'Codex', 'claude' => 'Claude', 'grok' => 'Grok' },
      'provider' => { 'openai' => 'OpenAI', 'anthropic' => 'Anthropic', 'xai' => 'xAI' }
    }.freeze

    module_function

    def required(value, field)
      raise Error, "Publication #{field} must be nonempty text." unless value.is_a?(String) && !value.strip.empty?

      checked(value, field)
    end

    # Fenced blocks and code spans hold intentional examples; only prose is checked.
    def prose(text)
      text.gsub(/^~~~.*?^~~~/m, '').gsub(/```.*?```/m, '').gsub(/(`+)(?:(?!\1).)*\1(?!`)/m, '')
    end

    # A summary is interpolated into raw HTML, so it must not be able to close its own tag.
    def summary_text(value, field)
      single_line(value, field).gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end

    def list(value, field)
      return [] if value.nil?
      raise Error, "Publication #{field} must be a list." unless value.is_a?(Array)

      value
    end

    def single_line(value, field)
      text = required(value, field)
      raise Error, "Publication #{field} must be a single line." if text.match?(/[\r\n]/)

      text
    end

    # Readers see a short commit; the link keeps the full SHA for anyone who needs it.
    # Anything other than a full SHA, such as UNKNOWN, is shown as given.
    def commit(sha, repository = nil)
      return sha unless sha.to_s.match?(/\A\h{40}\z/)

      short = "`#{sha[0, 7]}`"
      repository ? "[#{short}](https://github.com/#{repository}/commit/#{sha})" : short
    end

    # GitHub needs `\|` for a pipe anywhere in a cell. Outside code, escaping each backslash too
    # keeps a cell's own `\|` visible; inside a code span backslashes are already literal.
    def table_cell(text)
      text.gsub(CELL_PARTS) do |part|
        part.gsub(part.start_with?('`') ? '|' : /[\\|]/) { |character| "\\#{character}" }
      end
    end

    # The text a table_cell came from. Escaping adds no backticks, so the cell splits into the same parts.
    def table_cell_text(cell)
      cell.gsub(CELL_PARTS) { |part| part.gsub(part.start_with?('`') ? /\\(\|)/ : /\\([\\|])/, '\\1') }
    end

    def checked(value, field)
      return value unless prose(value).match?(ESCAPE)

      raise Error, "Publication #{field} contains a literal escape sequence; supply real line breaks."
    end

    def publisher_identity(content)
      header = identity(content['identity'])
      note = content['publisher_note']
      note ? "#{header}\n\n_#{single_line(note, 'publisher note')}_" : header
    end

    def identity(value)
      raise Error, 'Publication identity must be supplied.' unless value.is_a?(Hash)

      fields = IDENTITY_FIELDS.map { |field| identity_field(value[field], field) }
      "🤖 #{fields.join(' · ')}"
    end

    def identity_field(value, field)
      text = value.is_a?(String) && !value.strip.empty? ? single_line(value.strip, "identity #{field}") : 'UNKNOWN'
      DISPLAY_NAMES.fetch(field, {}).fetch(text.downcase, text)
    end
  end
end
