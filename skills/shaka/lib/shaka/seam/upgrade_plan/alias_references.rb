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

        def fenced_code_split(text)
          fenced = false
          text.each_line.partition do |line|
            body = line.sub(/\A(?:[ \t]*>)*/, '')
            fence = body.match?(/\A[ \t]*(?:```|~~~)/)
            fenced = !fenced if fence
            fenced || fence || body.match?(/\A(?: {4}|\t)/)
          end.map(&:join)
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
