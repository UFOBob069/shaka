# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/settings'

# Builds the settings snapshots that validation, review, and publication record.
module SettingsSnapshotHelper
  REVISION = 'a' * 40

  def snapshot(kind: 'trusted/team', ref: REVISION, **overrides)
    config = Object.new.tap do |settings|
      def settings.to_h = { 'merge' => { 'preference' => 'ask' } }
      def settings.config_path = nil
    end
    installation = { 'version' => '0.1.0', 'source' => { 'kind' => 'revision' } }
    Shaka::Evidence::PublicSettings.capture(config:, kind:, ref:, task_overrides: overrides, installation:)
  end

  def settings_block(current:, validation: [], review: [])
    checks = { 'validation' => validation, 'review' => review }.transform_values do |snapshots|
      snapshots.map { |settings| { 'original' => { 'public_settings' => settings } } }
    end
    verdict = { 'checks' => checks } unless (validation + review).empty?
    Shaka::PublicationSettings.new(verdict:, current:).detail.fetch('body')
  end
end
