# frozen_string_literal: true

require_relative 'private_delivery_helper'

class PrivateReviewSettingsTest < Minitest::Test
  include PrivateDeliveryFixture

  def test_private_instructions_reach_the_reviewer_and_explicit_choices_still_win
    with_trial do
      prepare_private_review
      result = JSON.parse(review_result('--model', 'claude-sonnet-4-6', '--effort', 'medium'))
      assert_reviewer_arguments(['--model', 'claude-sonnet-4-6'], ['--effort', 'medium'])
      assert_includes instructions, 'PRIVATE INSTRUCTIONS'
      assert_equal 'Individual settings (private source)', result['prompt_source']
    end
  end

  def test_reviewer_specific_private_instructions_replace_the_common_ones
    with_trial do
      prepare_private_review
      File.write(File.join(@root, '.agents/shaka/claude.md'), 'CLAUDE ONLY')
      update_private { |data| data['review']['local_review_agents'][0]['prompt_file'] = '.agents/shaka/claude.md' }
      review_result
      assert_includes instructions, 'CLAUDE ONLY'
      refute_includes instructions, 'PRIVATE INSTRUCTIONS'
    end
  end

  def test_tracked_review_prompt_reads_default_branch_bytes_after_a_branch_changes_it
    with_trial do
      commit_prompt('TRUSTED REVIEW RULES')
      @ref = git(@root, 'rev-parse', 'HEAD')
      update_private { |data| data['review']['prompt_file'] = 'review.md' }
      commit_prompt('CANDIDATE REVIEW RULES')
      result = JSON.parse(review_result(head: git(@root, 'rev-parse', 'HEAD')))
      assert_equal 'review.prompt_file review.md', result['prompt_source']
      assert_includes instructions, 'TRUSTED REVIEW RULES'
      refute_includes instructions, 'CANDIDATE REVIEW RULES'
    end
  end

  def test_private_round_limit_stops_the_review_loop
    with_trial do
      update_private { |data| data['review']['local_max_rounds'] = 1 }
      ledger = ['--ledger', File.join(@state, 'ledger.json')]
      review_result(*ledger)
      commit_prompt('A later change')
      review_result(*ledger, head: git(@root, 'rev-parse', 'HEAD'), error: 'round cap (1) reached')
    end
  end

  def test_private_prompt_edit_changes_the_settings_fingerprint
    with_trial do
      prepare_private_review
      before = settings_files
      File.write(File.join(@root, '.agents/shaka/review.md'), 'REVISED INSTRUCTIONS')
      refute_equal before, settings_files
    end
  end

  private

  # The reviewer's instructions, without the diff that follows them.
  def instructions
    JSON.parse(File.read(File.join(@state, 'reviewer.json')))['prompt'].split('SUPPORTING SOURCE DATA').first
  end

  def commit_prompt(text)
    File.write(File.join(@root, 'review.md'), text)
    commit(@root)
  end

  def settings_files
    _, fingerprint, = Shaka::Evidence::Inputs.capture(root: @root, ref: @ref, repository: 'owner/repo')
    fingerprint.fetch('components').fetch('files')
  end

  def prepare_private_review
    File.write(File.join(@root, '.agents/shaka/review.md'), 'PRIVATE INSTRUCTIONS')
    update_private do |data|
      data['review']['prompt_file'] = '.agents/shaka/review.md'
      data['review']['local_review_agents'] = [{ 'provider' => 'anthropic', 'model_family' => 'claude',
                                                 'model' => 'claude-opus-4-6', 'effort' => 'high' }]
    end
  end
end
