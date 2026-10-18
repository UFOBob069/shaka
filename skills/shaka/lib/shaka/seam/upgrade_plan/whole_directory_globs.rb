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

        # In a workflow only a `paths:` or `paths-ignore:` filter is a path pattern. A list-shaped entry anywhere
        # else, such as a matrix value or a line of a `run:` script, may reach a command, so it still blocks.
        def scan_workflow_glob_context(path, text)
          return unless workflow_file?(path) && unfiltered_glob_entry?(text)

          @references << { 'path' => path, 'kind' => 'workflow glob outside a path filter', 'paths' => [PATHS::DIRECTORY] }
          @blockers << "#{path}: old layout-directory pattern needs explicit repair"
        end

        def unfiltered_glob_entry?(text)
          filter = nil
          text.each_line.any? do |line|
            filter = filter_indent(filter, line)
            next false if line.match?(/\A[ \t]*paths(?:-ignore)?[ \t]*:/)

            line.match?(workflow_glob_entry) && !(filter && line.lstrip.start_with?('-'))
          end
        end

        # The indentation of the `paths:` key whose list this line belongs to, or nil outside one.
        def filter_indent(filter, line)
          width = line[/\A */].size
          return width if line.match?(/\A[ \t]*paths(?:-ignore)?[ \t]*:/)
          return filter if filter.nil? || line.strip.empty?

          width > filter || (width == filter && line.lstrip.start_with?('-')) ? filter : nil
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
