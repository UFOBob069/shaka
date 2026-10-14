# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/evidence/public_settings'

class PublicSettingsTest < Minitest::Test
  include EvidenceFixture

  def test_arbitrary_strings_markup_links_and_private_hashes_are_redacted
    secret = 'https://private.example/credential</details>'
    snapshot = Shaka::Evidence::PublicSettings::FIELDS.to_h { |field| [field, secret] }
    snapshot['commands'] = 'a' * 64
    snapshot['review.prompts'] = { 'prompt' => secret }
    public = Shaka::Evidence::PublicSettings.sanitize(snapshot)
    assert public.values.all?('REDACTED')
    refute_includes JSON.generate(public), secret
    refute_includes JSON.generate(public), 'a' * 64
  end

  def test_typed_values_and_known_overrides_survive_but_custom_values_do_not
    snapshot = { 'merge.preference' => 'auto', 'wip.include_checkout_path' => false,
                 'merge.limits.max_commits' => 3, 'overrides.reviewer' => 'openai/codex',
                 'overrides.effort' => 'medium', 'overrides.model' => 'private-model' }
    public = Shaka::Evidence::PublicSettings.sanitize(snapshot)
    assert_equal 'auto', public['merge.preference']
    refute public['wip.include_checkout_path']
    assert_equal 3, public['merge.limits.max_commits']
    assert_equal 'medium', public['overrides.effort']
    assert_equal 'REDACTED', public['overrides.model']
    assert_equal 'UNKNOWN', public['source']
  end

  def test_private_trial_reports_ask_and_public_installation_identity_only
    with_checkout do |root, ref|
      config = Shaka::Configuration.trusted(root:, ref:)
      installation = private_installation
      public = Shaka::Evidence::PublicSettings.capture(config:, kind: 'private/local', ref:,
                                                       task_overrides: {}, installation:)
      assert_equal 'ask', public['merge.private_trial_default']
      assert_equal 'private/local', public['source.configuration']
      assert_equal 'REDACTED', public['installation.revision']
      refute_includes JSON.generate(public), 'b' * 64
    end
  end

  def test_supported_opening_reviewers_survive_the_public_allowlist
    reviewers = { 'deepseek/openrouter' => 'deepseek/openrouter', ' OpenAI / Codex ' => 'openai/codex' }
    reviewers.each do |reviewer, expected|
      public = Shaka::Evidence::PublicSettings.sanitize('opening_check.reviewer' => reviewer)
      assert_equal expected, public.fetch('opening_check.reviewer')
    end
  end

  private

  def private_installation
    { 'version' => '0.1.0.pre.1',
      'source' => { 'kind' => 'revision', 'repository' => 'private/repo',
                    'revision' => 'a' * 40, 'content_sha256' => 'b' * 64 } }
  end
end
