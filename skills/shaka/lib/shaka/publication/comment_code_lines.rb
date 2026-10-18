# frozen_string_literal: true

module Shaka
  module CommentExcerpt
    # Follows which lines of a comment GitHub renders as code outside a list: fenced and indented
    # code blocks. A comment that also has a list is not quoted at all, so list items need no rules.
    class CodeLines
      # Three or more backticks or tildes open a fence; a backtick fence's info text has no backtick.
      FENCE = /\A {0,3}(?<marker>`{3,}(?=[^`]*\z)|~{3,})/
      # Four spaces, or a tab after fewer, indent a code block.
      INDENTED = /\A(?: {4}| {0,3}\t)/
      # A heading, a thematic break, or a quotation ends a paragraph on its own line, and so does
      # a setext underline below one.
      ENDS_PARAGRAPH = /\A {0,3}(?:\#{1,6}(?:\s|\z)|([-*_])(?:[ \t]*\1){2,}[ \t]*\z|>)/
      SETEXT = /\A {0,3}(?:=+|-+)[ \t]*\z/
      MARKER = /(?:[-+*]|\d{1,9}[.)])/
      LIST_ITEM = /\A {0,3}#{MARKER}(?:[ \t]|\z)/
      # Any run of three backticks or tildes, any indented text, or text set five columns past a
      # list marker may be code inside a list.
      CODE_SHAPED = /`{3}|~{3}|#{INDENTED}[ \t]*\S|\A {0,3}(?:#{MARKER}[ \t]+)*#{MARKER}(?: {5}|[ \t]*\t)/

      # A list can hold a fence or indented code at any depth, so its code cannot be told apart
      # from its prose without list rules.
      # A list-shaped line inside a fence that opens before any list, such as a diff, is code.
      def self.list_with_code?(text)
        code = new
        listed = text.lines.any? { |line| !code.code?(line) && list_item?(line.chomp) }
        listed && text.lines.any? { |line| line.match?(CODE_SHAPED) }
      end

      def self.list_item?(line) = line.match?(LIST_ITEM) && !line.match?(ENDS_PARAGRAPH)

      def initialize
        @fence = nil
        @paragraph = false
      end

      def code?(line)
        text = line.chomp
        return inside_fence?(text) if @fence
        return true if !@paragraph && text.match?(INDENTED)

        @fence = text[FENCE, :marker]
        @paragraph = !@fence && text.match?(/\S/) && !ends_paragraph?(text)
        !@fence.nil?
      end

      private

      # A line inside a fence is code. A run of the same character at least as long closes it.
      def inside_fence?(text)
        @fence = nil if text.match?(/\A {0,3}#{@fence}#{@fence[0]}*[ \t]*\z/)
        true
      end

      def ends_paragraph?(text) = text.match?(ENDS_PARAGRAPH) || (@paragraph && text.match?(SETEXT))
    end
  end
end
