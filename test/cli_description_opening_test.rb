# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'configuration_layout_fixture'
require_relative 'cli_opening_check_fakes'

# Nested description settings reach publication through both repository layouts.
class CliDescriptionOpeningTest < Minitest::Test
  include ConfigurationLayoutFixture
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Maintainers can choose how their PR opening is checked.'
  OPENING = { 'reviewer' => 'anthropic/claude', 'model' => 'chosen-model',
              'effort' => 'high', 'prompt_file' => '.agents/opening.md' }.freeze
  CODE_REVIEWER = { 'provider' => 'anthropic', 'model_family' => 'claude',
                    'model' => 'code-review-model', 'effort' => 'high' }.freeze

  def test_nested_settings_and_trusted_prompt_reach_the_reviewer_in_both_layouts
    %i[legacy current].each do |layout|
      with_nested_prompt(layout) { |root, dir| assert_trusted_selection(dir, root) }
    end
  end

  def test_opening_defaults_do_not_inherit_the_code_review_model_or_effort
    review = review_policy('local_review_agents' => [CODE_REVIEWER])
    with_repository('review' => review, 'pr_description' => { 'opening_check' => {} }) do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        assert_publication(dir, root, 'flagged', reviewer: 'anthropic/claude')
        args = JSON.parse(File.read(File.join(dir, 'claude-args.json')))
        refute_includes args, '--model'
        assert_includes args.each_cons(2).to_a, ['--effort', 'low']
      end
    end
  end

  def test_nested_disabled_setting_skips_the_reviewer
    with_repository('pr_description' => { 'opening_check' => { 'enabled' => false } }) do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        assert_publication(dir, root, 'disabled')
        refute_path_exists File.join(dir, 'claude-called')
      end
    end
  end

  def test_opening_choices_coexist_with_the_description_credit_opt_out
    description = { 'show_shaka_credit' => false, 'opening_check' => { 'reviewer' => 'anthropic/claude' } }
    with_repository('pr_description' => description) do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        assert_publication(dir, root, 'flagged')
        refute_includes File.read(File.join(dir, 'published.md')), 'PR prepared with'
      end
    end
  end

  private

  def with_nested_prompt(layout)
    with_repository('pr_description' => { 'opening_check' => OPENING }) do |root|
      File.write(File.join(root, '.agents/opening.md'), 'Trusted opening instructions.')
      move_to_new_layout(root) if layout == :current
      commit(root)
      File.write(File.join(root, '.agents/opening.md'), 'Candidate prompt replacement.')
      Dir.mktmpdir { |dir| yield root, dir }
    end
  end

  def assert_trusted_selection(dir, root)
    assert_publication(dir, root, 'flagged')
    args = JSON.parse(File.read(File.join(dir, 'claude-args.json'))).each_cons(2).to_a
    assert_includes args, ['--model', 'chosen-model']
    assert_includes args, ['--effort', 'high']
    prompt = File.read(File.join(dir, 'opening-prompt.txt'))
    assert_includes prompt, 'Trusted opening instructions.'
    refute_includes prompt, 'Candidate prompt replacement.'
  end

  def assert_publication(dir, root, expected, reviewer: nil)
    output, error, status = run_description(dir, root:, ref: true, reviewer:)
    assert_predicate status, :success?, error
    assert_equal expected, JSON.parse(output).dig('opening', 'status')
  end
end
