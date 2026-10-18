# frozen_string_literal: true

module Shaka
  class Seam
    class UpgradePlan
      # Removes old-directory `**` entries that still cover every moved path: a list entry in a GitHub Actions
      # workflow, or a line of an ignore or CODEOWNERS file.
      module WholeDirectoryGlobs
        private

        def without_whole_directory_globs(line, path)
          if workflow_file?(path)
            line.gsub(workflow_glob_entry, '\k<prefix>')
          elsif ignore_or_owners_file?(path)
            line.gsub(ignore_glob_entry, '\k<prefix>')
          else
            line
          end
        end

        # A list entry inside a workflow block scalar, such as a `run: |` script, is command text, so it still blocks.
        def scan_workflow_block_glob(path, text)
          return unless workflow_file?(path)
          return unless block_scalar_lines(text).any? { |line| line.match?(workflow_glob_entry) }

          @references << { 'path' => path, 'kind' => 'workflow block glob', 'paths' => [PATHS::DIRECTORY] }
          @blockers << "#{path}: old layout-directory pattern needs explicit repair"
        end

        def block_scalar_lines(text)
          indent = nil
          text.each_line.select do |line|
            width = line[/\A */].size
            inside = indent && (line.strip.empty? || width > indent)
            indent = nil unless inside
            indent = width if !inside && line.match?(/:[ \t]*[|>][-+0-9]*[ \t]*(?:#.*)?$/)
            inside
          end
        end

        def workflow_file?(path) = path.to_s.match?(%r{\A\.github/workflows/[^/]+\.ya?ml\z})

        def ignore_or_owners_file?(path)
          name = File.basename(path.to_s)
          name == 'CODEOWNERS' || name.match?(/\A\.[\w-]*ignore\z/)
        end

        def workflow_glob_entry
          item = %q(["']?[^\s"',\]]+["']?[ \t]*,[ \t]*)
          %r{^(?<prefix>[ \t]*(?:-[ \t]*|[\w.-]+[ \t]*:[ \t]*\[[ \t]*(?:#{item})*)["']?)
             #{Regexp.escape(PATHS::DIRECTORY)}/\*\*(?![[:alnum:]_./*?\[\{-])}xo
        end

        def ignore_glob_entry
          %r{^(?<prefix>[ \t]*!?/?)#{Regexp.escape(PATHS::DIRECTORY)}/\*\*(?![[:alnum:]_./*?\[\{-])}o
        end
      end
    end
  end
end
