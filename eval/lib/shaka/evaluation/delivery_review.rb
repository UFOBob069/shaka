# frozen_string_literal: true

require 'digest'
require 'json'
require 'time'

module Shaka
  module Evaluation
    # A receipt records GitHub's evidence, without deciding whether its prose proves delivery.
    module DeliveryReview
      QUERY = <<~GRAPHQL
        query($id: ID!) {
          node(id: $id) {
            ... on PullRequestReview {
              id fullDatabaseId state body createdAt updatedAt submittedAt
              author { login } commit { oid }
              pullRequest { number state headRefOid repository { nameWithOwner } }
            }
          }
        }
      GRAPHQL

      module_function

      def read(bytes, expected)
        response = decode(bytes)
        row = response.fetch('data').fetch('node')
        valid = !response.key?('errors') && matches?(row, expected) && timestamps?(row)
        raise IOError, 'Invalid delivery review readback' unless valid

        row.merge('fullDatabaseId' => row.fetch('fullDatabaseId').to_s,
                  'body_digest' => "sha256:#{Digest::SHA256.hexdigest(row.fetch('body'))}")
      rescue JSON::ParserError, KeyError, TypeError, NoMethodError, ArgumentError
        raise IOError, 'Invalid delivery review readback'
      end

      def decode(bytes)
        text = bytes.dup.force_encoding(Encoding::UTF_8)
        raise IOError, 'Invalid delivery review encoding' unless text.valid_encoding?

        JSON.parse(text)
      end

      def matches?(row, expected)
        review_matches?(row, expected) && pull_matches?(row.fetch('pullRequest'), expected) && row['body'].is_a?(String)
      end

      def review_matches?(row, expected)
        actual = [row.fetch('id'), row.fetch('fullDatabaseId').to_s, row.dig('commit', 'oid'), row['state']]
        wanted = expected.values_at('node_id', 'review_id', 'head') + ['COMMENTED']
        actual == wanted && row.dig('author', 'login')&.casecmp?(expected.fetch('actor'))
      end

      def pull_matches?(pull, expected)
        [pull['state'], pull['headRefOid'], pull['number']] == ['OPEN', *expected.values_at('head', 'number')] &&
          pull.dig('repository', 'nameWithOwner')&.casecmp?(expected.fetch('repository'))
      end

      def timestamps?(row)
        created, submitted, updated = %w[createdAt submittedAt updatedAt].map do |field|
          value = row.fetch(field)
          return false unless value.is_a?(String) && /\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z\z/.match?(value)

          Time.iso8601(value)
        end
        submitted.between?(created, updated)
      end
    end
  end
end
