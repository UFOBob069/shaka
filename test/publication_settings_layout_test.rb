# frozen_string_literal: true

require_relative 'settings_snapshot_helper'

# The full table appears only for settings a reader cannot look up in the repository.
class PublicationSettingsLayoutTest < Minitest::Test
  include SettingsSnapshotHelper

  def test_only_a_trusted_revision_links_to_the_repository
    sha = 'a' * 40
    trusted = Shaka::SettingsTable.source({ 'source' => 'trusted/team', 'source.revision' => sha }, 'acme/widgets')
    local = Shaka::SettingsTable.source({ 'source' => 'private/local', 'source.revision' => sha }, 'acme/widgets')
    assert_equal "trusted/team at [`aaaaaaa`](https://github.com/acme/widgets/commit/#{sha})", trusted
    assert_equal 'private/local at `aaaaaaa`', local
  end

  def test_settings_kept_out_of_the_repository_keep_every_value_behind_a_second_disclosure
    summary, values = bound.split('<details>', 2)
    assert_includes summary, "| Before push: validation | private/local at `#{REVISION[0, 7]}` | validate |"
    refute_includes summary, '| merge.preference |'
    assert_includes values, '| merge.preference | ask | ask | ask |'
    assert values.end_with?('</details>'), 'the values disclosure must close inside the block'
  end

  def test_settings_from_an_unmerged_settings_pr_keep_their_table_too
    assert_includes settings_block(current: snapshot(kind: 'preview/local')), '| merge.preference | ask |'
  end

  def test_without_results_the_table_holds_only_the_current_column
    body = settings_block(current: local)
    assert_includes body, '| Setting | Current merge input (not evidence) |'
    assert_includes body, '| merge.preference | ask |'
  end

  def test_each_reviewer_gets_its_own_column_headed_by_its_name
    reviews = [local(reviewer: 'openai/codex'), local(reviewer: 'anthropic/claude')]
    body = settings_block(current: local, validation: [local(command: 'validate')], review: reviews)
    assert_includes body, '| Setting | Before push: validation | Review: openai/codex | Review: anthropic/claude |'
    assert_includes body, '| overrides.reviewer | UNKNOWN | openai/codex | anthropic/claude | UNKNOWN |'
  end

  def test_a_result_that_recorded_no_settings_is_named_above_the_table_instead_of_shown
    body = settings_block(current: local, validation: [nil], review: [local(reviewer: 'openai/codex')])
    note = body.index('UNKNOWN there: **Before push: validation**')
    assert_operator note, :<, body.index('| Setting | Review: openai/codex |')
  end

  def test_settings_redacted_in_every_shown_column_share_one_line
    [bound, settings_block(current: local)].each do |body|
      refute_includes body, '| commands |'
      assert_match(/^.*REDACTED.*: commands, paths, .*local_changes$/, body)
    end
  end

  def test_settings_unknown_in_every_shown_column_share_one_line
    [bound, settings_block(current: local)].each do |body|
      refute_includes body, '| defaults_changed |'
      assert_match(/^UNKNOWN in every column: .*overrides\.effort.*defaults_changed/, body)
    end
  end

  def test_a_setting_recorded_in_one_column_keeps_its_row
    assert_includes bound, '| overrides.command | validate | UNKNOWN | UNKNOWN |'
  end

  def test_a_redacted_setting_keeps_its_row_while_another_shown_column_is_unknown
    body = bound(validation: local(command: 'validate').except('commands'))
    assert_includes body, '| commands | UNKNOWN | REDACTED | REDACTED |'
    refute_includes body, ': commands, paths'
  end

  def test_a_setting_redacted_for_an_invalid_value_keeps_its_row
    body = settings_block(current: local.merge('merge.preference' => 'bogus'))
    assert_includes body, '| merge.preference | REDACTED |'
  end

  private

  def local(**) = snapshot(kind: 'private/local', **)

  def bound(validation: local(command: 'validate'))
    settings_block(current: local, validation: [validation], review: [local(reviewer: 'openai/codex')])
  end
end
