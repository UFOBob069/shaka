# frozen_string_literal: true

require_relative 'private_delivery_helper'

class PrivateDeliverySettingsTest < Minitest::Test
  include PrivateDeliveryFixture

  def test_explicit_review_choices_win_without_using_private_prompt_instructions
    with_trial do
      prepare_private_review
      result = JSON.parse(review_result('--model', 'claude-sonnet-4-6', '--effort', 'medium'))
      trace = JSON.parse(File.read(File.join(@state, 'reviewer.json')))
      assert_reviewer_arguments(['--model', 'claude-sonnet-4-6'], ['--effort', 'medium'])
      refute_includes trace['prompt'], 'PRIVATE INSTRUCTIONS'
      assert_equal 'Shaka default', result['prompt_source']
    end
  end

  def test_description_and_walkthrough_read_changed_private_prose_limits
    with_trial do
      publish_delivery
      update_private { |data| data['prose_limits'] = { 'max_sentence_words' => 2 } }
      publish_description(*evidence_files, exit_code: 1, error: 'limit 2')
      invoke('walkthrough', '--head', @ref, '--content-file', walkthrough_file, exit_code: 1, error: 'limit 2')
    end
  end

  def test_opening_reads_private_reviewer_enablement_and_prompt
    with_trial do
      prepare_private_opening
      output = publish_description(*evidence_files, opening: true)
      assert_equal 'flagged', output.dig('opening', 'status')
      assert_includes File.read(File.join(@state, 'opening-prompt.txt')), 'Name the reader-facing subject.'
      update_private { |data| data['opening_check']['external_enabled'] = false }
      output = publish_description(*evidence_files, opening: true)
      assert_includes output.dig('opening', 'reason'), 'external_enabled'
    end
  end

  def test_trusted_team_settings_win_in_both_layouts_after_adoption
    %i[new legacy].each do |layout|
      with_trial do
        adopt_team(layout)
        publish_delivery
        update_team_candidate
        assert_reviewer('anthropic/claude')
        assert_empty invoke('handoff')['owed']
        assert_equal 'seam', invoke('pr')['requiredChecksSource']
      end
    end
  end

  private

  def prepare_private_review
    File.write(File.join(@root, '.agents/shaka/review.md'), 'PRIVATE INSTRUCTIONS')
    update_private do |data|
      data['review']['prompt_file'] = '.agents/shaka/review.md'
      data['review']['local_review_agents'] = [{ 'provider' => 'anthropic', 'model_family' => 'claude',
                                                 'model' => 'claude-opus-4-6', 'effort' => 'high' }]
    end
  end

  def prepare_private_opening
    write_executable(@state, 'claude', fake_claude)
    path = '.agents/shaka/opening.md'
    File.write(File.join(@root, path), 'Name the reader-facing subject.')
    update_private { |data| data['opening_check'] = { 'external_enabled' => true, 'prompt_file' => path } }
  end

  def adopt_team(layout)
    update_private { |data| data['merge']['required_checks'] = ['team-gate'] }
    git(@root, 'add', '-f', '.agents/shaka')
    FileUtils.mkdir_p(File.join(@root, '.agents/bin'))
    move_to_legacy_layout(@root) if layout == :legacy
    git(@root, 'add', '-A') if layout == :legacy
    commit(@root)
    @ref = git(@root, 'rev-parse', 'HEAD')
    alter_pull { |pull| pull['snapshot']['headRefOid'] = @ref }
  end

  def update_team_candidate
    path = Shaka::Configuration.worktree(root: @root).config_path
    data = YAML.safe_load_file(File.join(@root, path))
    data['merge'].delete('required_checks')
    data['review']['local_review_agents'] = [{ 'provider' => 'xai', 'model_family' => 'grok' }]
    File.write(File.join(@root, path), YAML.dump(data))
  end
end
