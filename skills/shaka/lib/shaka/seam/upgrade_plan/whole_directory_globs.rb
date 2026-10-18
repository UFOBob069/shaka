# frozen_string_literal: true

require 'yaml'

module Shaka
  class Seam
    class UpgradePlan
      # Removes old-directory `**` globs that still cover every moved path: event path filters in a GitHub
      # Actions workflow, or lines of an ignore or CODEOWNERS file.
      module WholeDirectoryGlobs
        private

        def without_whole_directory_globs(line, path)
          if filtered_workflows.include?(path)
            line.gsub(terminal_glob, '')
          elsif ignore_or_owners_file?(path)
            line.gsub(ignore_glob_entry, '\k<prefix>')
          else
            line
          end
        end

        # A workflow is exempt only when every occurrence of the glob is an `on.<event>.paths` or `paths-ignore`
        # value. A matrix value, a `run:` script, YAML aliases, or a parse failure keeps it blocking.
        def note_workflow_filters(path, text)
          filtered_workflows << path if workflow_file?(path) && every_glob_filtered?(text)
        end

        def every_glob_filtered?(text)
          occurrences = text.scan(terminal_glob).size
          occurrences.positive? && occurrences == filter_globs(text)
        end

        def filter_globs(text)
          events = workflow_events(text).values.grep(Hash)
          filters = events.flat_map { |event| event.values_at('paths', 'paths-ignore') }
          filters.flatten.count { |value| value.is_a?(String) && value.match?(whole_glob_value) }
        end

        # YAML 1.1 reads an unquoted `on` key as true.
        def workflow_events(text)
          document = YAML.safe_load(text, permitted_classes: [], permitted_symbols: [], aliases: false)
          events = document.is_a?(Hash) ? document.fetch('on') { document[true] } : nil
          events.is_a?(Hash) ? events : {}
        rescue Psych::Exception
          {}
        end

        def filtered_workflows = (@filtered_workflows ||= [])

        def workflow_file?(path) = path.to_s.match?(%r{\A\.github/workflows/[^/]+\.ya?ml\z})

        def ignore_or_owners_file?(path)
          name = File.basename(path.to_s)
          name == 'CODEOWNERS' || name.match?(/\A\.[\w-]*ignore\z/)
        end

        def terminal_glob
          %r{(?<![[:alnum:]_.-])#{Regexp.escape(PATHS::DIRECTORY)}/\*\*(?![[:alnum:]_./*?\[\{-])}o
        end

        def whole_glob_value = %r{\A!?/?#{Regexp.escape(PATHS::DIRECTORY)}/\*\*\z}o

        def ignore_glob_entry
          %r{^(?<prefix>[ \t]*!?/?)#{Regexp.escape(PATHS::DIRECTORY)}/\*\*(?![[:alnum:]_./*?\[\{-])}o
        end
      end
    end
  end
end
