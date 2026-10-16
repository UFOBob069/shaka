# frozen_string_literal: true

require_relative '../error'

module Shaka
  class Claim
    # The query for a task given as a sentence: its description slug stands in for a work item.
    Description = Data.define(:slug) do
      def initialize(slug:)
        unless slug.is_a?(String) && slug.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
          raise Error, 'Expected a lowercase description slug such as add-button-counter.'
        end

        super
      end
    end
  end
end
