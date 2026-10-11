# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'shaka/trusted_config_source'

class RepositoryConfigOpeningProviderTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_requires_a_model_for_opening_reviewers_without_a_default
    ['xai/grok', 'deepseek/openrouter', ' XAI/Grok ', ' DeepSeek/OpenRouter '].each do |reviewer|
      with_repository('opening_check' => { 'reviewer' => reviewer }) do |root|
        assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
      end
    end
  end

  def test_openrouter_settings_follow_the_existing_adapter_contract
    model = 'deepseek/deepseek-v4.1-flash'
    reviewer = { 'reviewer' => 'deepseek/openrouter' }
    [{ 'model' => 'another-model' }, { 'model' => model, 'effort' => 'medium' }].each do |options|
      opening = reviewer.merge(options)
      with_repository('pr_description' => { 'opening_check' => opening }) do |root|
        assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
      end
    end
  end

  def test_openrouter_uses_the_default_low_effort
    settings = { 'reviewer' => 'deepseek/openrouter', 'model' => 'deepseek/deepseek-v4.1-flash' }
    with_repository('opening_check' => settings) do |root|
      assert_equal 'low', Shaka::RepositoryConfig.load(root:).opening_check.fetch('effort')
    end
  end
end
