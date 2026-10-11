# frozen_string_literal: true

require_relative 'opening_schema'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates settings grouped by the PR description they affect.
    class PrDescriptionSchema
      include Validation

      def initialize(description)
        @description = description
      end

      def validate
        mapping!(@description, 'pr_description')
        keys!(@description, [], %w[show_shaka_credit opening_check], 'pr_description')
        validate_credit
        return unless @description.key?('opening_check')

        OpeningSchema.new(@description['opening_check'], label: 'pr_description.opening_check').validate
      end

      private

      def validate_credit
        return unless @description.key?('show_shaka_credit')

        enum!(@description['show_shaka_credit'], [true, false],
              'pr_description.show_shaka_credit must be true or false')
      end
    end
  end
end
