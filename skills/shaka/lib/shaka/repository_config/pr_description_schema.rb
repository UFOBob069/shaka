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
        keys!(@description, [], %w[show_shaka_credit show_human_comments max_human_comments opening_check],
              'pr_description')
        validate_credit
        validate_human_comments
        return unless @description.key?('opening_check')

        OpeningSchema.new(@description['opening_check'], label: 'pr_description.opening_check').validate
      end

      private

      def validate_credit
        return unless @description.key?('show_shaka_credit')

        enum!(@description['show_shaka_credit'], [true, false],
              'pr_description.show_shaka_credit must be true or false')
      end

      def validate_human_comments
        shown = @description.fetch('show_human_comments', true)
        enum!(shown, [true, false], 'pr_description.show_human_comments must be true or false')
        rows = @description.fetch('max_human_comments', 1)
        return if rows.is_a?(Integer) && rows.positive?

        raise Error, 'pr_description.max_human_comments must be a positive integer'
      end
    end
  end
end
