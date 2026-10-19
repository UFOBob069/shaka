# frozen_string_literal: true

require 'uri'

module Shaka
  module Evaluation
    # The fixture's artifact grammar; review prose is data, never instructions.
    module AskWalkthrough
      SPAN = /(?<ticks>`+).*?(?<!`)\k<ticks>(?!`)/m

      module_function

      def valid?(body, plan, files)
        visible = unfenced(body)
        lines = visible.lines.map(&:strip).reject(&:empty?)
        prose = visible.gsub(SPAN, 'code')
        markers(plan).include?(lines.last) && structure?(prose.lines.map(&:strip)) && code_link?(prose, plan, files)
      end

      # Use CodeLinks' delimiter/indentation rules; an invalid closer keeps following text inside the example.
      def unfenced(body)
        fence = nil
        body.lines.filter_map do |line|
          if fence
            fence = nil if closes_fence?(line, fence)
            next
          end
          fence = line[/\A[ \t]*(`{3,}|~{3,})/, 1]
          line unless fence
        end.join
      end

      def closes_fence?(line, fence)
        line.strip.match?(/\A#{Regexp.escape(fence[0])}{#{fence.length},}\z/)
      end

      # Adapt the pinned producer's short linked and bare full-SHA forms without importing product code.
      def markers(plan)
        head, repository = plan.values_at('head', 'repository')
        references = [head[0, 7], head].map { |label| "[`#{label}`](https://github.com/#{repository}/commit/#{head})" }
        [*references, "`#{head}`"].map do |reference|
          "_Walkthrough for commit #{reference}. This is a COMMENT, not an approval._"
        end
      end

      def structure?(lines)
        lines.any? { |line| /\A🤖 .+ · .+ · .+\z/.match?(line) } && lines.any? { |line| /\A## \S/.match?(line) }
      end

      def code_link?(body, plan, files)
        body.scan(%r{https://github\.com/[^\s<>)]+}).any? { |text| link?(text, plan, files) }
      end

      def link?(text, plan, files)
        uri = URI.parse(text)
        prefix = "/#{plan.fetch('repository')}/blob/#{plan.fetch('head')}/"
        anchor = /\AL([1-9]\d*)(?:-L([1-9]\d*))?\z/.match(uri.fragment.to_s)
        return false unless uri.path.start_with?(prefix) && uri.query.nil? && anchor

        bounds?(files[URI::DEFAULT_PARSER.unescape(uri.path.delete_prefix(prefix))], anchor)
      rescue URI::InvalidURIError
        false
      end

      def bounds?(count, anchor)
        first, last = anchor.captures.map { |line| line&.to_i }
        count.is_a?(Integer) && first <= count && (last.nil? || last.between?(first, count))
      end
    end
  end
end
