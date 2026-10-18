# frozen_string_literal: true

require 'cgi'
require_relative '../error'

module Shaka
  # One review comment to publish. `summaries` lists every disclosure summary in the order GitHub must show them;
  # `reports` lists the reviewer reports it quotes verbatim.
  LocalReviewCommentPart = Struct.new(:key, :body, :attestation, :summaries, :reports) do
    def size = "<!-- shaka:reply:#{key} -->\n#{body}".length

    # Reports are published verbatim, so a stray fence or disclosure tag in one can swallow the rest
    # of the comment. GitHub's own rendering decides that; a regex over Markdown cannot.
    def check_rendering!(html)
      closing = %r{<p\b[^>]*>#{Regexp.escape(CGI.escapeHTML(attestation))}</p>\s*\z}
      disclosures = [html.scan(/<details\b/).size, html.scan('</details>').size]
      return if html.match?(closing) && disclosures == [summaries.size] * 2 && in_order?(html)

      raise Error, 'A review report leaves its markup open or adds disclosure tags, so GitHub would not show ' \
                   'each round collapsed with the attestation last. Fix the report and publish again.'
    end

    private

    def in_order?(html)
      offset = 0
      summaries.all? do |summary|
        found = html.index("<summary>#{summary}</summary>", offset)
        offset = found + 1 if found
      end
    end
  end
end
