# frozen_string_literal: true

require_relative 'settings_preview_fixture'
require 'shaka/publication/settings'

class SettingsPreviewConsumersTest < Minitest::Test
  include SettingsPreviewFixture

  def test_preview_selects_reviewers_and_count_together
    with_preview_repository do |root, _trusted, _preview|
      data = settings(root)
      trusted = set_trusted_count(root, data)
      data['review']['local_review_count'] = 1
      data['review']['local_review_agents'] = [{ 'provider' => 'xai', 'model_family' => 'grok' },
                                               { 'provider' => 'openai', 'model_family' => 'codex' }]
      select_preview(root, write_settings(root, data))
      assert_equal ['xai/grok'], reviewer(root, trusted)['reviewers']
      assert_equal %w[xai/grok openai/codex], reviewer(root, trusted, '--count', '2')['reviewers']
    end
  end

  def test_preview_applies_opening_prompt_prose_and_location_preferences
    with_preview_repository do |root, trusted, _preview|
      select_publication_preview(root)
      result = Shaka::OpeningPublication.new(root:, ref: trusted).call('Maintainers can try settings.')
      assert_includes result['prompt'], 'Selected preview writing instructions.'
      refute_includes result['prompt'], 'Unselected candidate instructions.'
      assert_equal 19, Shaka::ProseLimits.from_ref(root:, ref: trusted).to_h['max_sentence_words']
      snapshot = Shaka::PublicationSettings.current_settings(root:, ref: trusted,
                                                             repository: 'owner/repo', required: true)
      refute_predicate Shaka::PublicationSettings.new(current: snapshot), :include_locations?
    end
  end

  def test_evidence_uses_the_selected_layout_when_the_preview_migrates_it
    with_preview_repository do |root, trusted, _preview|
      use_new_layout(root)
      select_preview(root, commit(root))
      config, fingerprint, kind = Shaka::Evidence::Inputs.capture(root:, ref: trusted, repository: 'owner/repo')
      assert_equal '.agents/shaka/config.yml', config.config_path
      assert_equal 'preview/local', kind
      refute_empty fingerprint['digest']
    end
  end

  private

  def set_trusted_count(root, data)
    data['review']['local_review_count'] = 2
    write_settings(root, data)
  end

  def select_publication_preview(root)
    data = settings(root)
    data['opening_check'] = { 'external_enabled' => false, 'prompt_file' => '.agents/preview-opening.md' }
    data['prose_limits'] = { 'max_sentence_words' => 19 }
    data['wip'] = { 'include_locations' => false }
    File.write(File.join(root, '.agents/preview-opening.md'), 'Selected preview writing instructions.')
    select_preview(root, write_settings(root, data))
    File.write(File.join(root, '.agents/preview-opening.md'), 'Unselected candidate instructions.')
  end

  def reviewer(root, trusted, *)
    output, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root, '--ref', trusted,
                                           '--implementer', 'anthropic/claude', *)
    assert_predicate status, :success?, error
    JSON.parse(output)
  end
end
