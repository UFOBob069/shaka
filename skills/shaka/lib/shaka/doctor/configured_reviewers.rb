# frozen_string_literal: true

require_relative '../reviewer_selection'
require_relative '../reviewer_settings'
require_relative '../repository_config'

module Shaka
  class Doctor
    # Lists catalog notices for every reviewer a repository configures, labeled by the setting that chose it.
    module ConfiguredReviewers
      CHECKPOINT = RepositoryConfig::PostImplementationSchema

      module_function

      def notices(config)
        local = Array(config.review['local_review_agents']).flat_map do |entry|
          next [] unless entry.is_a?(Hash)

          labeled('Code review', entry.values_at('provider', 'model_family').join('/'), entry)
        end
        local + opening(config.opening_check) + checkpoint(config.review.fetch(CHECKPOINT::KEY, {}))
      end

      # Without its own reviewer, the opening check uses a code reviewer, which is already checked.
      def opening(settings)
        return [] unless settings['enabled'] && settings['external_enabled'] != false && settings['reviewer']

        labeled('Opening check', settings['reviewer'], settings)
      end

      # Mirrors PostImplementationRunner#discard_model?: a reviewer other than the default
      # does not inherit the default reviewer's model.
      def checkpoint(settings)
        effective = CHECKPOINT::DEFAULTS.merge(settings)
        return [] unless effective['enabled']

        reviewer = CHECKPOINT.reviewer(effective['reviewer'])
        inherited = !settings.key?('model') && reviewer != CHECKPOINT.reviewer(CHECKPOINT::DEFAULTS['reviewer'])
        labeled('Checkpoint', reviewer, effective.merge('model' => inherited ? nil : effective['model']))
      end

      def labeled(label, identity, settings)
        identity = ReviewerSelection.parse(identity).values.map(&:downcase).join('/')
        ReviewerSettings.notices(identity, model: settings['model'], effort: settings['effort']).map do |notice|
          notice.merge('summary' => "#{label}: #{notice.fetch('summary')}")
        end
      end
    end
  end
end
