# frozen_string_literal: true

require 'uri'
require 'time'
require 'date'
require_relative 'finding'
require_relative 'assessment_references'

module Shaka
  # A later judgment is data, separate from the reviewer's original finding and its triage.
  class LocalReviewAssessment
    include LocalReviewAssessmentReferences

    CHOICES = {
      'problem' => %w[confirmed refuted uncertain disputed],
      'remedy' => %w[supported unnecessary incorrect harmful excessive inconclusive],
      'implementation' => %w[correct defective uncertain],
      'attention' => %w[action_required decision_required none]
    }.freeze
    ACTIONS = %w[not_attempted as_proposed differently partially reverted replaced].freeze
    ROLES = %w[maintainer task_owner reviewer observer agent].freeze
    FIELDS = (CHOICES.keys + %w[id finding recommendation action by revision observed_at recorded_at
                                rationale evidence supersedes]).freeze
    attr_reader :data

    def self.actor!(value)
      raise Error, 'Assessment by must contain a name and role.' unless
        value.is_a?(Hash) && value.keys.sort == %w[name role]

      PublicationText.single_line(value['name'], 'assessment actor name')
      raise Error, "Assessment actor role must be one of #{ROLES.join(', ')}." unless ROLES.include?(value['role'])

      value
    end

    def initialize(data)
      raise Error, 'Assessment must be an object with known fields.' unless
        data.is_a?(Hash) && (data.keys - FIELDS).empty?

      @data = data
      check_identity!
      check_judgments!
      check_references!
      check_dates!
    end

    def id = data.fetch('id')
    def finding = data.fetch('finding')
    def supersedes = data.fetch('supersedes', [])
    def recommendation = data['recommendation']

    def self.sha!(value, field)
      raise Error, "Assessment #{field} must be a full SHA." unless
        value.is_a?(String) && value.match?(LocalReviewEvidence::SHA)
    end

    private

    def check_identity!
      %w[id finding].each { |key| identifier!(data[key], key) }
      self.class.actor!(data['by'])
      PublicationText.single_line(data['rationale'], 'assessment rationale')
    end

    def check_dates!
      %w[observed_at recorded_at].each { |key| date!(data[key], key) if data.key?(key) }
    end

    def identifier!(value, field)
      raise Error, "Assessment #{field} must be a finding-style identifier." unless
        value.is_a?(String) && value.match?(LocalReviewFinding::ID)
    end

    def check_judgments!
      raise Error, 'Assessment needs at least one judgment or action.' unless
        data.keys.intersect?(CHOICES.keys + ['action'])

      check_choices!
      action!(data['action']) if data.key?('action')
    end

    def check_choices!
      CHOICES.each do |key, values|
        raise Error, "Assessment #{key} must be one of #{values.join(', ')}." if
          data.key?(key) && !values.include?(data[key])
      end
    end

    def action!(value)
      raise Error, 'Assessment action needs a taken value and known fields.' unless
        value.is_a?(Hash) && (value.keys - %w[taken commits attribution]).empty? && ACTIONS.include?(value['taken'])
      raise Error, 'Assessment action attribution must be direct or uncertain.' if
        value.key?('attribution') && !%w[direct uncertain].include?(value['attribution'])

      action_commits!(value)
    end

    def action_commits!(value)
      commits = list!(value.fetch('commits', []), 'action commits')
      commits.each { |sha| self.class.sha!(sha, 'action commit') }
      raise Error, 'A not_attempted action cannot name implementation commits.' if
        value['taken'] == 'not_attempted' && !commits.empty?
    end
  end
end
