# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # Checks GitHub's rendering of text Shaka writes: no literal escape outside code, and every table rendered.
  module RenderedProse
    ESCAPE = /\\[nrt]/
    SEPARATOR = /\A\s*\|[\s|:-]*-{3}[\s|:-]*\|\s*\z/

    module_function

    def check!(body, html)
      if bare(html).match?(ESCAPE)
        raise Error, 'Rendered output contains a literal escape sequence; supply real line breaks.'
      end

      expected = PublicationText.prose(body).lines.count { |line| line.match?(SEPARATOR) }
      rendered = html.scan('<table').size
      return if rendered >= expected

      raise Error, "GitHub rendered #{rendered} of #{expected} table(s); check the separator column count."
    end

    # Escapes GitHub preserved inside a code element were written on purpose.
    def bare(html) = html.gsub(%r{<pre\b.*?</pre>}m, '').gsub(%r{<code\b.*?</code>}m, '')
  end
end
