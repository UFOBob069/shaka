# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Detects a variable assigned the old layout directory.
      module AliasReferences
        private

        def alias_reference?(text, path = nil)
          return true if bare_directory_dependency?(text)
          return assignment_alias?(text, code_assignment) unless prose_file?(path)

          code, prose = fenced_code_split(text)
          assignment_alias?(code, code_assignment) || assignment_alias?(prose, prose_assignment)
        end

        def assignment_alias?(text, assignment)
          mapping = %r{\b[A-Za-z_]\w*\s*:[ \t]+[^\r\n]*#{Regexp.escape(PATHS::DIRECTORY)}/?(?=[ \t\r\n#'";]|$)}o
          [text, normalize_shell_fragments(text)].any? { |source| source.match?(assignment) || source.match?(mapping) }
        end

        # Splits Markdown into code (fenced or indented blocks, plus inline code spans) and the remaining prose.
        def fenced_code_split(text)
          code, prose = code_block_partition(text)
          spans = prose.scan(/(`+)(.+?)\1/).map(&:last)
          [[code, *spans].join("\n"), prose]
        end

        def code_block_partition(text)
          opening = nil
          text.each_line.partition do |line|
            body = line.sub(/\A(?:[ \t]*>)*/, '')
            marker = body[/\A[ \t]*(`{3,}|~{3,})/, 1]
            code = opening || marker || body.match?(/\A(?: {4}|\t)/)
            opening = next_fence(opening, body, marker)
            code
          end.map(&:join)
        end

        # A fence closes only on a bare fence of the same character and at least the opening length.
        def next_fence(opening, body, marker)
          return marker unless opening

          closing = marker&.start_with?(opening[0]) && marker.length >= opening.length &&
                    body.match?(/\A[ \t]*[`~]+[ \t]*$/)
          closing ? nil : opening
        end

        def code_assignment
          %r{\b[A-Za-z_]\w*\s*[+?:]?=[^\r\n]*#{Regexp.escape(PATHS::DIRECTORY)}(?=/|[^[:alnum:]_.-]|$)}o
        end

        # Outside code blocks in Markdown, the directory must sit in the assigned value, with whitespace only inside
        # quotes or parentheses.
        def prose_assignment
          value = /(?:[^\s"'(]|"[^"\r\n]*"|'[^'\r\n]*')*(?:"[^"\r\n]*|'[^'\r\n]*|\([^\r\n]*?)?/.source
          %r{\b[A-Za-z_]\w*\s*[+?:]?=[ \t]*#{value}#{Regexp.escape(PATHS::DIRECTORY)}(?=/|[^[:alnum:]_.-]|$)}o
        end

        def prose_file?(path) = path.to_s.match?(/\.(?:md|markdown|mdx)\z/i)
      end
    end
  end
end
