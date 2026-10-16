# frozen_string_literal: true

require_relative '../defaults'
require_relative '../error'

module Shaka
  class Claim
    # Compiles a repository branch-name template, or the tracker's branch name, into a matcher for remote heads.
    class Names
      DEFAULT = Defaults.fetch('branches', 'name')
      # Stands in for {issue} when a task has no work item. Fixed rather than a setting because
      # the collision matcher below parses it out of other sessions' branch names.
      AD_HOC = 'ad-hoc'
      WILDCARDS = { 'login' => '[^/]+', 'host' => '[^/]+', 'description' => '.+' }.freeze

      def initialize(query:, template:, description: nil, exact: nil)
        @query = query
        @description = description
        @template = template
        @exact = exact
        return unless description && !(template || DEFAULT).include?('{description}')

        raise Error, 'branches.name needs {description} to name a task without a work item.'
      end

      def reported
        return @exact || @template || DEFAULT unless @description

        (@template || DEFAULT).gsub('{issue}', AD_HOC).gsub('{description}', @description)
      end

      def cover?(name)
        return name.match?(template_pattern) if @description

        name == @exact || name.match?(issue_token_pattern) || template_match?(name)
      end

      private

      # Trackers such as Linear lowercase the key in the branch names they generate.
      def issue_token_pattern = %r{(?:^|/)#{Regexp.escape(@query)}-}i

      def template_match?(name)
        return false if @template.nil? || @template.strip.empty?

        name.match?(template_pattern)
      end

      def template_pattern
        @template_pattern ||= begin
          pieces = (@template || DEFAULT).split(/\{(login|host|issue|description)\}/)
          regex = pieces.each_with_index.map { |piece, index| index.even? ? Regexp.escape(piece) : token_regex(piece) }
          Regexp.new("\\A#{regex.join}\\z")
        end
      end

      def token_regex(token)
        return "(?i:#{Regexp.escape(@description ? AD_HOC : @query)})" if token == 'issue'
        return Regexp.escape(@description) if @description && token == 'description'

        WILDCARDS.fetch(token)
      end
    end
  end
end
