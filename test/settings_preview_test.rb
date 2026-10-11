# frozen_string_literal: true

require_relative 'settings_preview_fixture'

class SettingsPreviewTest < Minitest::Test
  include SettingsPreviewFixture

  def test_explicit_preview_selects_settings_and_leaves_trusted_policy_alone
    with_preview_repository do |root, trusted, preview|
      select_preview(root, preview)
      config, _, kind = Shaka::Evidence::Inputs.resolve_source(root, trusted)
      assert_equal 'preview/local', kind
      assert_equal 'preview-model', config.review['local_review_agents'].first['model']
      assert_equal 'ask', Shaka::Configuration.trusted(root:, ref: trusted).merge['preference']
      assert_empty git(root, 'status', '--porcelain')
    end
  end

  def test_preview_resumes_in_a_fresh_command_and_does_not_follow_a_moved_branch
    with_preview_repository do |root, trusted, preview|
      select_preview(root, preview)
      assert_fresh_reviewer(root, trusted)
      git(root, 'checkout', '-qb', 'untrusted')
      _, _, kind = Shaka::Evidence::Inputs.resolve_source(root, trusted)
      assert_equal 'trusted/team', kind
      git(root, 'checkout', '-q', 'feature')
      assert_equal 'preview/local', Shaka::Evidence::Inputs.resolve_source(root, trusted).last
    end
  end

  def test_public_evidence_reports_the_selected_policy_without_private_source_details
    with_preview_repository do |root, trusted, preview|
      select_preview(root, preview)
      snapshot = Shaka::Evidence::Inputs.capture(root:, ref: trusted, repository: 'owner/repo').last
      assert_equal 'auto', snapshot['merge.preference']
      assert_equal trusted, snapshot['source.revision']
      refute_includes JSON.generate(snapshot), preview
    end
  end

  def test_new_layout_selects_and_pins_the_settings_commit
    with_preview_repository(layout: :new) do |root, trusted, preview|
      select_preview(root, preview)
      before = capture(root, trusted)
      changed = create_preview_commit(root, model: 'updated-preview-model')
      assert_equal before, capture(root, trusted)
      select_preview(root, changed)
      refute_equal before, capture(root, trusted)
      assert_equal '.agents/shaka/config.yml', Shaka::Evidence::Inputs.resolve_source(root, trusted).first.config_path
    end
  end

  def test_stopping_preview_restores_the_team_source_and_invalidates_evidence
    with_preview_repository do |root, trusted, preview|
      before = capture(root, trusted)
      select_preview(root, preview)
      refute_equal before, capture(root, trusted)
      _, error, status = Open3.capture3(COMMAND, 'seam', 'preview', 'stop', '--root', root)
      assert_predicate status, :success?, error
      assert_equal before, capture(root, trusted)
    end
  end

  def test_ordinary_team_fingerprint_keeps_the_existing_source_identity
    with_preview_repository do |root, trusted, _preview|
      identity = { 'repository' => 'owner/repo', 'layout' => '.agents/agent-workflow.yml',
                   'trusted_default_commit' => trusted, 'kind' => 'trusted/team',
                   'configuration_blob' => git(root, 'rev-parse', "#{trusted}:.agents/agent-workflow.yml").strip }
      expected = Shaka::Configuration::FingerprintCanonical.digest('source', identity)
      assert_equal expected, capture(root, trusted).dig('components', 'source')
    end
  end

  def test_new_layout_preview_uses_the_task_checkout_legacy_commands
    with_preview_repository do |root, trusted, _preview|
      git(root, 'checkout', '-q', 'settings')
      use_new_layout(root)
      preview = commit(root)
      git(root, 'checkout', '-q', 'feature')
      select_preview(root, preview)
      config = Shaka::Evidence::Inputs.resolve_source(root, trusted).first
      assert_equal '.agents/shaka/config.yml', config.config_path
      assert_equal '.agents/bin/test', config.to_h.fetch('commands').fetch('test')
    end
  end

  private

  def assert_fresh_reviewer(root, trusted)
    output, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root, '--ref', trusted,
                                           '--implementer', 'anthropic/claude')
    assert_predicate status, :success?, error
    assert_equal(['openai/codex'], JSON.parse(output)['considered'].map { |entry| entry['reviewer'] })
  end
end

class SettingsPreviewBoundaryTest < Minitest::Test
  include SettingsPreviewFixture

  def test_a_candidate_selection_file_cannot_activate_preview
    with_preview_repository do |root, trusted, preview|
      File.write(File.join(root, 'shaka-settings-preview.json'),
                 JSON.generate('version' => 1, 'branch' => 'feature', 'ref' => preview))
      assert_equal 'trusted/team', Shaka::Evidence::Inputs.resolve_source(root, trusted).last
    end
  end

  def test_a_linked_worktree_does_not_inherit_the_selection
    with_preview_repository do |root, trusted, preview|
      select_preview(root, preview)
      Dir.mktmpdir do |parent|
        linked = File.join(parent, 'linked')
        git(root, 'worktree', 'add', '-q', '-b', 'other-task', linked, trusted)
        assert_equal 'trusted/team', Shaka::Evidence::Inputs.resolve_source(linked, trusted).last
      end
    end
  end

  def test_first_setup_can_be_explicitly_selected_without_a_default_branch_seam
    with_preview_repository do |root, _trusted, preview|
      absent = remove_trusted_setup(root)
      select_preview(root, preview)
      assert_equal 'preview/local', Shaka::Evidence::Inputs.resolve_source(root, absent).last
      refute_empty capture(root, absent)['digest']
      policy = Shaka::TrustedConfigSource.from_ref(root:, ref: absent, private_trial: true)
      assert_equal 'auto', policy.merge['preference']
      assert_raises(Shaka::Error) { Shaka::Configuration.trusted(root:, ref: absent) }
    end
  end

  def test_preview_does_not_hide_invalid_trusted_settings
    with_preview_repository do |root, _trusted, preview|
      File.write(File.join(root, '.agents/agent-workflow.yml'), "version: invalid\n")
      invalid = commit(root)
      git(root, 'checkout', '-q', 'feature~1')
      git(root, 'checkout', '-qb', 'repair')
      select_preview(root, preview)
      assert_raises(Shaka::Error) { Shaka::Evidence::Inputs.resolve_source(root, invalid) }
    end
  end

  def test_moving_refs_are_rejected_without_creating_a_selection
    with_preview_repository do |root, _trusted, _preview|
      selector = Shaka::Configuration::SettingsPreview.new(root:)
      assert_raises(Shaka::Error) { selector.start('settings') }
      assert_equal 'inactive', selector.status['status']
    end
  end
end
