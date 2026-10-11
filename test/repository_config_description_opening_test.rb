# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/trusted_config_source'

class RepositoryConfigDescriptionOpeningTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_nested_settings_use_the_existing_effective_opening_api
    settings = { 'reviewer' => 'openai/codex', 'model' => 'chosen-model' }
    with_repository('pr_description' => { 'opening_check' => settings }) do |root|
      config = Shaka::RepositoryConfig.load(root:)
      assert_equal settings.merge('enabled' => true, 'effort' => 'low'), config.opening_check
      assert_equal config.opening_check, config.to_h.fetch('opening_check')
      assert_equal({ 'show_shaka_credit' => true }, config.to_h.fetch('pr_description'))
    end
  end

  def test_empty_description_settings_keep_the_opening_defaults
    with_repository('pr_description' => {}) do |root|
      assert_equal({ 'enabled' => true, 'effort' => 'low' }, Shaka::RepositoryConfig.load(root:).opening_check)
    end
  end

  def test_rejects_two_places_for_the_same_settings
    with_repository('opening_check' => { 'enabled' => true },
                    'pr_description' => { 'opening_check' => { 'enabled' => false } }) do |root|
      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
      assert_includes error.message, 'Use pr_description.opening_check or opening_check, not both'
    end
  end

  def test_rejects_invalid_nested_settings_with_their_full_path
    [true, { 'unknown' => true }, { 'opening_check' => nil },
     { 'opening_check' => { 'model' => 'missing-reviewer' } }].each do |description|
      with_repository('pr_description' => description) do |root|
        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
        assert_includes error.message, 'pr_description'
      end
    end
  end

  def test_nested_prompt_is_checked_locally
    settings = { 'prompt_file' => '.agents/missing.md' }
    with_repository('pr_description' => { 'opening_check' => settings }) do |root|
      error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
      assert_includes error.message, 'prompt_file does not exist'
    end
  end
end
