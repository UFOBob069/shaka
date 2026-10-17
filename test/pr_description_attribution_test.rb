# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require 'shaka/repository_config'
require 'shaka/publication/publication'

class PrDescriptionAttributionTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  SUMMARY = 'Reviewers can see the changed behavior.'
  CREDIT = '_PR prepared with [Shaka](https://shaka.shakacode.com/)._'

  def test_default_contract_enables_attribution
    with_repository do |root|
      config = Shaka::RepositoryConfig.load(root:)
      assert_equal Shaka::RepositoryConfig::DEFAULT_PR_DESCRIPTION, config.pr_description
      assert_equal config.pr_description, config.to_h.fetch('pr_description')
    end
  end

  def test_setting_accepts_only_a_boolean_and_known_keys
    [{ 'show_shaka_credit' => 'false' }, { 'show_shaka_credit' => nil },
     { 'attribution' => false }, { 'enabled' => false }, false].each do |section|
      with_repository('pr_description' => section) do |root|
        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
        assert_includes error.message, 'pr_description'
      end
    end
  end

  def test_credit_appears_once_at_the_end
    settings = Shaka::PublicationSettings.new(current: { 'pr_description.show_shaka_credit' => true })
    rendered = Shaka::Publication.description(description_content, nil, nil, settings)
    assert_equal 1, rendered.scan(CREDIT).size
    assert rendered.end_with?("</details>\n\n#{CREDIT}\n"), rendered
  end

  def test_disabled_attribution_keeps_the_summary_and_other_evidence
    settings = Shaka::PublicationSettings.new(current: { 'pr_description.show_shaka_credit' => false })
    rendered = Shaka::Publication.description(description_content, nil, nil, settings)
    refute_includes rendered, CREDIT
    assert_includes rendered, SUMMARY
    assert_includes rendered, 'Checkpoint'
    assert_includes rendered, 'Execution provenance'
  end

  def test_unavailable_settings_do_not_override_an_opt_out
    [nil, {}, { 'pr_description.show_shaka_credit' => 'UNKNOWN' }].each do |current|
      settings = Shaka::PublicationSettings.new(current:)
      refute_includes Shaka::Publication.description(description_content, nil, nil, settings), CREDIT
    end
  end

  def test_replies_and_walkthroughs_have_no_description_credit
    content = { 'identity' => { 'agent' => 'Codex' }, 'summary' => SUMMARY, 'head' => 'a' * 40 }
    refute_includes Shaka::Publication.comment(content), CREDIT
    refute_includes Shaka::Publication.walkthrough(content), CREDIT
  end

  def test_publication_uses_trusted_opt_out_not_candidate_configuration
    with_repository('pr_description' => { 'show_shaka_credit' => false }) do |root|
      commit(root)
      enable_candidate_attribution(root)
      body = published_body(root)
      refute_includes body, CREDIT
      assert_includes body, 'Current merge input (not evidence): trusted/team at'
    end
  end

  def published_body(root)
    Dir.mktmpdir do |dir|
      _output, error, status = run_description(dir, root:, ref: fixture_ref(root))
      assert_predicate status, :success?, error
      File.read(File.join(dir, 'published.md'))
    end
  end

  def enable_candidate_attribution(root)
    path = File.join(root, '.agents/agent-workflow.yml')
    config = YAML.safe_load_file(path)
    config['pr_description']['show_shaka_credit'] = true
    File.write(path, YAML.dump(config))
  end

  def test_publication_without_an_explicit_setting_has_the_default_credit
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, error, status = run_description(dir, root:, ref: fixture_ref(root))
        assert_predicate status, :success?, error
        assert_includes File.read(File.join(dir, 'published.md')), CREDIT
      end
    end
  end
end

class PrDescriptionCheckpointCommandTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = PrDescriptionAttributionTest::COMMAND
  SUMMARY = PrDescriptionAttributionTest::SUMMARY

  def test_description_command_uses_the_live_rest_pull_head
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, error, status = run_description(dir, root:, ref: fixture_ref(root))
        assert_predicate status, :success?, error
        assert_includes File.read(File.join(dir, 'published.md')), '**No recommendation yet**'
      end
    end
  end

  def test_description_command_refuses_stale_summary_without_publishing
    @checkpoint_head = 'd' * 40
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, _error, status = run_description(dir, root:, ref: fixture_ref(root))
        refute_predicate status, :success?
        refute_path_exists File.join(dir, 'published.md')
      end
    end
  end

  # A description with a checkpoint reads this account's published checkpoint; none is published here.
  def fake_gh
    super.sub('else abort', "when 'user' then puts JSON.generate('login' => 'agent')\n" \
                            "when %r{issues/1/comments} then puts '[]'\nelse abort")
  end

  def description_content
    super.merge('checkpoint' => { 'head' => @checkpoint_head || ('c' * 40),
                                  'next_action' => 'Justin: choose the next direction.' })
  end
end
