# frozen_string_literal: true

require_relative '../error'
require_relative '../publication_sections'
require_relative '../usage/usage_records'
require_relative 'human_comments'
require_relative 'provenance_history'
require_relative 'steps_besides_merging'

module Shaka
  # A quoted marker stays in the raw description, so the next read sees two and stops.
  # Markers this helper emits into that description are ignored; any other shaka
  # marker is refused before GitHub is written. Marker names are unchanged.
  module PublicationMarkers
    TOKEN = %r{<!-- /?shaka:[^\n>]*-->|<!-- /?shaka:\S*}
    HUMAN_CLOSE = /^#{Regexp.escape(HumanComments::CLOSE_MARK)}$/
    PROVENANCE = %r{#{Regexp.escape(ProvenanceHistory::PREFIX)}\{.*?\} -->\n\n(?=</details>)}
    USAGE_OPEN = /\A#{Regexp.escape(UsageRecords::BEGIN_PREFIX)}[^\n]* -->\n/
    USAGE_CLOSE = /#{Regexp.escape(UsageRecords::END_MARK)}\z/

    module_function

    def refuse!(body)
      marker = quoted(without_emitted(body))
      return unless marker

      raise Error, "Publication body contains a Shaka marker (`#{marker}`); remove it before publishing."
    end

    def quoted(text)
      token = text[TOKEN]
      token[%r{\A<!-- /?shaka:\S*(?: -->)?}] if token
    end

    def without_emitted(body)
      text = strip_structural(body.dup)
      text.gsub(UsageRecords::BLOCK) { |block| block.sub(USAGE_OPEN, '').sub(USAGE_CLOSE, '') }
    end

    def strip_structural(text)
      text.sub!(section_marker(StepsBesidesMerging::MARKER, StepsBesidesMerging::HEADING), '')
      text.sub!(section_marker(PublicationSections::MARKER, PublicationSections::DECISIONS_HEADING), '')
      text.sub!(PROVENANCE, '')
      strip_human(text)
      text
    end

    def strip_human(text)
      opened = text.sub!(section_marker(HumanComments::OPEN_MARK, HumanComments::HEADING), '')
      text.sub!(HUMAN_CLOSE, '') if opened
      text
    end

    def section_marker(marker, heading)
      /#{Regexp.escape(marker)}\n(?=## #{Regexp.escape(heading)}\n)/
    end
  end
end
