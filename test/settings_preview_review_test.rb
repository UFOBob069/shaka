# frozen_string_literal: true

require_relative 'review_prompt_file_test'
require_relative 'support/post_implementation_fixture'
require 'shaka/configuration/settings_preview'

class SettingsPreviewReviewTest < Minitest::Test
  include ReviewPromptFileFixture

  def test_preview_prompt_model_and_round_cap_reach_the_reviewer
    with_repository({ 'prompt_file' => '.agents/review-prompt.md' }) do |root, base, _head, bin|
      head = preview_review(root)
      fake_codex(bin, head)
      Shaka::Configuration::SettingsPreview.new(root:).start(head)
      ledger = File.join(bin, 'ledger.json')
      output, error, status = run_review(root, base, head, bin, '--ledger', ledger)
      assert_predicate status, :success?, "#{output} #{error}"
      assert_equal 20, JSON.parse(File.read(ledger))['local_max_rounds']
      assert_preview_inputs(root, JSON.parse(output))
    end
  end

  private

  def preview_review(root)
    path = File.join(root, '.agents/agent-workflow.yml')
    data = YAML.safe_load_file(path)
    data['review']['local_max_rounds'] = 20
    data['review']['local_review_agents'] = [{ 'provider' => 'openai', 'model_family' => 'codex',
                                               'model' => 'preview-model' }]
    File.write(path, YAML.dump(data))
    commit!(root, 'preview settings')
    git!(root, 'rev-parse', 'HEAD').strip
  end

  def assert_preview_inputs(root, result)
    assert_equal 'Local settings preview (private source)', result['prompt_source']
    trace = JSON.parse(File.read(File.join(root, 'trace.json')))
    assert_includes trace['args'].each_cons(2).to_a, ['-m', 'preview-model']
    assert_includes trace['prompt'].split('SUPPORTING SOURCE DATA').first, 'Candidate instructions'
  end

  def fake_codex(bin, head)
    write_executable(bin, 'codex', <<~RUBY)
      #!/usr/bin/env ruby
      require 'json'
      File.write(ENV.fetch('REVIEW_TRACE'), JSON.generate(prompt: STDIN.read, args: ARGV))
      File.write(ARGV.fetch(ARGV.index('-o') + 1), "REVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\n")
    RUBY
  end
end

class SettingsPreviewCheckpointTest < Minitest::Test
  include PostImplementationFixture

  def test_explicitly_selected_preview_can_disable_the_checkpoint
    with_repository do |root, base, _head, bin|
      head = preview_checkpoint(root)
      fake_checkpoint(bin, head)
      Shaka::Configuration::SettingsPreview.new(root:).start(head)
      result, status = run_checkpoint(root, base, head, bin)
      assert_predicate status, :success?, result.inspect
      assert_equal 'opted_out', result['status']
      refute_path_exists File.join(root, 'trace.json')
    end
  end

  private

  def preview_checkpoint(root)
    path = File.join(root, '.agents/agent-workflow.yml')
    data = YAML.safe_load_file(path)
    data['review']['post_implementation'] = { 'enabled' => false, 'model' => 'preview-model',
                                              'prompt_file' => '.agents/private-checkpoint.md' }
    File.write(File.join(root, '.agents/private-checkpoint.md'), 'Assess the intended outcome.')
    File.write(path, YAML.dump(data))
    commit!(root, 'preview checkpoint')
    git!(root, 'rev-parse', 'HEAD').strip
  end
end
