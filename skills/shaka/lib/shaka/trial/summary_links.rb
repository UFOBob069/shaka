# frozen_string_literal: true

require 'uri'
require_relative '../error'

module Shaka
  module Trial
    # Names the repository behind each github.com link in a trial summary. Every GitHub mention
    # must be a link this can read; anything else is refused unchecked.
    module SummaryLinks
      # A github.com link with an optional scheme, www., and port, not continuing another host or address.
      # The path runs to whitespace, because Markdown and browsers keep reading past quotes and brackets.
      LINK = %r{(?<![\w.@/:-])(?:(?:(?<scheme>https?):)?//)?(?:www\.)?github\.com(?::(?<port>\d+))?
                (?<path>/\S*)}ix
      # Sentence punctuation and Markdown closers that end a link without belonging to it.
      LINK_END = /[.,;:!?)\]`"'*_~]+\z/
      # The same ending from its first closer, which a Markdown destination or quote ends at.
      CLOSER_END = /[)\]`"'][.,;:!?)\]`"'*_~]*\z/

      module_function

      def repositories(summary)
        links = []
        remainder = summary.gsub(LINK) do
          links << Regexp.last_match
          ' '
        end
        raise Error, 'Write each GitHub link in the summary as https://github.com/OWNER/REPO.' if
          mentions_github?(remainder) || links.any? { |link| mentions_github?(link[:path]) }

        links.flat_map { |link| link_repositories(link) }.uniq
      end

      # A bare autolink drops trailing punctuation, but a Markdown destination keeps what precedes its
      # closing bracket or quote, so both readings are checked.
      def link_repositories(link)
        raise Error, 'GitHub links in the summary must use the default port.' unless default_port?(link)

        full = link[:path]
        paths = [full.sub(LINK_END, '')]
        paths << full.sub(CLOSER_END, '') if full.match?(CLOSER_END)
        paths.uniq.map { |path| repository(path, full) }
      end

      # Markdown drops backslash escapes; browsers decode percent escapes, fold compatibility characters,
      # map ideographic full stops, and drop invisible characters in a host. The search does all of that.
      def mentions_github?(text)
        URI::DEFAULT_PARSER.unescape(text.delete('\\')).scrub('').unicode_normalize(:nfkc).tr('。', '.')
                           .gsub(/\p{Default_Ignorable_Code_Point}/, '').downcase.include?('github.com')
      end

      def repository(path, full)
        segments = path_segments(path)
        raise Error, 'GitHub links in the summary must not contain . or .. path segments.' if
          segments.intersect?(%w[. ..]) || trailing_dot_segment?(path, full)

        Array(segments[1, 2]).join('/')
      end

      # Trimming sentence punctuation must not hide a final .. segment; a final . stays in the same place.
      def trailing_dot_segment?(path, full)
        path.end_with?('/') && full[path.length, 2] == '..'
      end

      def default_port?(link)
        link[:port].nil? || link[:port].to_i == (link[:scheme]&.downcase == 'http' ? 80 : 443)
      end

      def path_segments(path)
        URI::DEFAULT_PARSER.unescape(URI.parse("https://github.com#{path}").path).split('/')
      rescue URI::InvalidURIError
        raise Error, 'Supply full GitHub repository URLs in the summary.'
      end
    end
  end
end
