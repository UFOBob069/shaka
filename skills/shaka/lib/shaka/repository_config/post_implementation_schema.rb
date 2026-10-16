# frozen_string_literal: true

require_relative 'validation'
require_relative '../defaults'
require_relative '../reviewer_selection'

module Shaka
  class RepositoryConfig
    # Execution choices for product validation, separate from technical review.
    class PostImplementationSchema
      include Validation

      KEY = 'post_implementation'
      KEYS = %w[enabled reviewer model effort prompt_file].freeze
      EFFORTS = { 'openai/codex' => %w[low medium high xhigh max],
                  'anthropic/claude' => %w[low medium high xhigh max],
                  'xai/grok' => %w[low medium high] }.freeze
      DEFAULTS = Defaults.fetch('review', KEY)

      def self.reviewer(identity) = ReviewerSelection.parse(identity).values.map(&:downcase).join('/')

      def initialize(settings) = @settings = settings

      def validate
        label = "review.#{KEY}"
        mapping!(@settings, label)
        keys!(@settings, [], KEYS, label)
        validate_enabled(label)
        reviewer = self.class.reviewer(@settings.fetch('reviewer', DEFAULTS.fetch('reviewer')))
        raise Error, "#{label}.reviewer must be a supported provider/family" unless EFFORTS.key?(reviewer)

        validate_choices(label, reviewer)
        prompt_path!(@settings['prompt_file'], "#{label}.prompt_file") if @settings.key?('prompt_file')
      end

      private

      def validate_enabled(label)
        return unless @settings.key?('enabled')
        return if [true, false].include?(@settings['enabled'])

        raise Error, "#{label}.enabled must be true or false"
      end

      def validate_choices(label, reviewer)
        ReviewSchema.model_name!(@settings['model'], "#{label}.model") if @settings.key?('model')
        return unless @settings.key?('effort')
        return if EFFORTS.fetch(reviewer).include?(@settings['effort'])

        raise Error, "#{label}.effort must be #{EFFORTS.fetch(reviewer).join(', ')} for #{reviewer}"
      end
    end
  end
end
