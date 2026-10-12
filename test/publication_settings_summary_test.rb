# frozen_string_literal: true

require_relative 'settings_snapshot_helper'

class PublicationSettingsSummaryTest < Minitest::Test
  include SettingsSnapshotHelper

  COMMITTED = "trusted/team at #{REVISION}".freeze

  def test_the_block_opens_on_its_status_then_the_current_settings
    status, _note, current = settings_block(current: snapshot).split("\n\n")
    assert_equal 'UNKNOWN: rerun missing evidence.', status
    assert_equal "Current merge input (not evidence): #{COMMITTED}; Shaka 0.1.0 (installation: revision)", current
  end

  def test_committed_settings_get_one_row_per_operation_instead_of_a_table_of_settings
    body = settings_block(current: snapshot, validation: [snapshot(command: 'validate')],
                          review: [snapshot(reviewer: 'openai/codex')])
    assert_includes body, "| Before push: validation | #{COMMITTED} | validate |"
    assert_includes body, "| Review | #{COMMITTED} | openai/codex |"
    refute_includes body, '<details>'
    refute_includes body, '| merge.preference |'
  end

  def test_each_reviewer_gets_its_own_row
    reviews = [snapshot(reviewer: 'openai/codex'), snapshot(reviewer: 'anthropic/claude', effort: 'medium')]
    body = settings_block(current: snapshot, validation: [snapshot(command: 'validate')], review: reviews)
    assert_includes body, "| Review | #{COMMITTED} | openai/codex |"
    assert_includes body, "| Review | #{COMMITTED} | anthropic/claude, medium effort |"
  end

  def test_results_that_recorded_the_same_settings_still_get_a_row_each
    reviews = [snapshot(reviewer: 'openai/codex')] * 2
    body = settings_block(current: snapshot, validation: [snapshot(command: 'validate')], review: reviews)
    assert_equal 2, body.scan("| Review | #{COMMITTED} | openai/codex |").size
  end

  def test_a_result_recorded_at_another_settings_revision_shows_that_revision
    earlier = snapshot(ref: 'b' * 40, command: 'validate')
    body = settings_block(current: snapshot, validation: [earlier], review: [snapshot(reviewer: 'openai/codex')])
    assert_includes body, "| Before push: validation | trusted/team at #{'b' * 40} | validate |"
    assert_includes body, "Current merge input (not evidence): #{COMMITTED}"
  end

  def test_a_result_that_recorded_no_settings_reads_unknown
    body = settings_block(current: snapshot, validation: [nil], review: [snapshot(reviewer: 'openai/codex')])
    assert_includes body, '| Before push: validation | UNKNOWN | UNKNOWN |'
  end

  def test_without_results_there_are_no_operation_rows
    body = settings_block(current: snapshot)
    refute_includes body, '| Operation |'
    refute_includes body, '| Review |'
  end

  def test_unread_settings_stay_unknown
    assert_includes Shaka::PublicationSettings.new.detail.fetch('body'),
                    'Current merge input (not evidence): UNKNOWN; Shaka UNKNOWN'
  end
end
