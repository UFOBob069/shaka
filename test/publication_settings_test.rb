# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/publication/settings'

class PublicationSettingsTest < Minitest::Test
  include EvidenceFixture

  def test_bound_results_render_snapshots_without_exposing_fingerprints
    with_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate')
      review = review_check(root, ref)
      with_results(validation, review) do |options|
        body = prepare(root, ref, options).detail.fetch('body')
        assert_includes body, "| Before push: validation | trusted/team at #{ref} | validate |"
        assert_includes body, "| Review | trusted/team at #{ref} | openai/codex |"
        refute_includes body, validation.dig('settings', 'digest')
      end
    end
  end

  def test_stale_results_refuse_publication_without_relabeling_original_evidence
    with_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate')
      review = review_check(root, ref)
      head = changed_candidate(root)
      with_results(validation, review) do |options|
        original = File.read(options.fetch(:review).first)
        assert_raises(Shaka::Error) { prepare(root, ref, options, head:) }
        assert_equal original, File.read(options.fetch(:review).first)
      end
    end
  end

  def test_settings_mismatch_and_missing_validation_require_rerun
    with_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate')
      with_results(validation, review_check(root, ref)) do |options|
        assert_raises(Shaka::Error) { prepare(root, ref, options.except(:validation)) }
        File.write(File.join(root, '.agents/bin/validate'), "#!/bin/sh\nexit 0\n# changed\n")
        assert_raises(Shaka::Error) { prepare(root, ref, options) }
      end
    end
  end

  def test_older_results_do_not_gain_a_retroactive_settings_snapshot
    with_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate').except('public_settings')
      review = review_check(root, ref).except('public_settings')
      with_results(validation, review) do |options|
        body = prepare(root, ref, options).detail.fetch('body')
        assert_includes body, '| Before push: validation | UNKNOWN | UNKNOWN |'
        assert_includes body, "Current merge input (not evidence): trusted/team at #{ref}"
      end
    end
  end

  def test_editing_only_public_settings_cannot_publish_false_values
    with_checkout do |root, ref|
      validation = run_check(root, ref, command: 'validate')
      validation.fetch('public_settings')['merge.preference'] = 'ask'
      with_results(validation, review_check(root, ref)) do |options|
        assert_raises(Shaka::Error) { prepare(root, ref, options) }
      end
    end
  end

  def test_unknown_settings_are_visible_on_unfinished_descriptions
    body = Shaka::PublicationSettings.new.detail.fetch('body')
    assert_includes body, 'UNKNOWN: rerun missing evidence'
    assert_includes body, 'Current merge input (not evidence): UNKNOWN'
  end

  def test_unfinished_team_description_preserves_its_location_choice
    with_checkout do |root, ref|
      settings = prepare(root, ref, {})
      assert_predicate settings, :include_checkout_path?
      assert_includes settings.detail.fetch('body'), "Current merge input (not evidence): trusted/team at #{ref}"
    end
  end

  private

  def changed_candidate(root)
    File.write(File.join(root, 'feature'), 'changed')
    git(root, 'add', 'feature')
    commit(root)
    git(root, 'rev-parse', 'HEAD')
  end

  def prepare(root, ref, options, head: ref)
    pull = { 'changed_files' => 0, 'head' => { 'sha' => head }, 'base' => { 'sha' => ref } }
    Shaka::PublicationSettings.prepare(root:, ref:, pull:,
                                       options: options.merge(root:), github: empty_diff)
  end

  def empty_diff
    Object.new.tap do |github|
      def github.repository = 'shakacode/shaka'
      def github.number = 1
      def github.api_list(_path) = []
    end
  end

  def with_results(validation, review)
    Tempfile.create(['validation-', '.json']) do |first|
      Tempfile.create(['review-', '.json']) do |second|
        first.write(JSON.generate(validation))
        second.write(JSON.generate(review))
        first.flush
        second.flush
        yield validation: [first.path], review: [second.path]
      end
    end
  end
end
