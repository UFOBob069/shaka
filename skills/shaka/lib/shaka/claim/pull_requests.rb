# frozen_string_literal: true

require_relative 'references'
require_relative 'comments'

module Shaka
  class Claim
    # Filters an open-PR inventory; search only selects extra comment reads.
    class PullRequests
      PR_FIELDS = %w[number title url headRefName].freeze
      PR_JSON = (PR_FIELDS + %w[body closingIssuesReferences]).join(',')

      def initialize(query:, names:, capture:)
        @query = query
        @names = names
        @capture = capture
      end

      def call
        return by_branch_name unless @query

        inventory = pull_requests([], PR_JSON)
        searched = search_numbers
        raise Error, 'GitHub PR inventory changed during ownership search.' unless
          (searched - inventory_numbers(inventory)).empty?

        inventory.filter_map { |pr| pr.slice(*PR_FIELDS) if covered?(pr, searched) }
      end

      private

      # A task without a work item has no number for text, references, or comments to mention.
      def by_branch_name = pull_requests([], PR_FIELDS.join(',')).filter { |pr| @names.cover?(pr.fetch('headRefName')) }

      def inventory_numbers(inventory)
        inventory.map do |pr|
          References.new(query: @query, pull_request: pr)
          pr.fetch('number')
        end
      end

      def search_numbers
        pull_requests(['--search', @query], 'number').map do |pr|
          unless pr.is_a?(Hash) && pr['number'].is_a?(Integer)
            raise Error, 'GitHub returned incomplete search metadata.'
          end

          pr.fetch('number')
        end
      end

      def covered?(pull_request, searched)
        References.new(query: @query, pull_request: pull_request).cover? ||
          @names.cover?(pull_request.fetch('headRefName')) ||
          (searched.include?(pull_request.fetch('number')) &&
            Comments.new(query: @query, capture: @capture).cover?(pull_request))
      end

      def pull_requests(search, fields)
        parsed = JSON.parse(@capture.call(['gh', 'pr', 'list', *search, '--state', 'open', '--limit', '1000', '--json',
                                           fields]))
        raise Error, 'GitHub pull request list must be an array.' unless parsed.is_a?(Array)
        raise Error, 'GitHub pull request list reached its limit; ownership is incomplete.' if parsed.length >= 1000

        parsed
      rescue JSON::ParserError
        raise Error, 'GitHub returned invalid JSON.'
      end
    end
  end
end
