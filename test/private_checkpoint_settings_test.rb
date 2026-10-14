# frozen_string_literal: true

require_relative 'private_delivery_helper'

class PrivateCheckpointSettingsTest < Minitest::Test
  include PrivateDeliveryFixture

  CHOICES = { 'reviewer' => 'anthropic/claude', 'model' => 'claude-sonnet-4-6', 'effort' => 'high',
              'prompt_file' => '.agents/shaka/checkpoint.md' }.freeze
  COMMITS = { 'totalCount' => 1 }.freeze
  PACKET = %w[problem audience outcome validation repair_history].to_h { |key| [key, 'Text'] }.freeze

  def test_private_opt_out_is_recorded_then_accepted_by_final_preparation
    with_trial do
      update_private { |data| data['review']['post_implementation'] = { 'enabled' => false } }
      result = run_checkpoint
      assert_equal 'opted_out', result['status']
      assert_includes result['reason'], 'enabled is false'
      record_on_pull(result)
      assert_equal 10, invoke('squash-message', '--head', @ref, '--content-file', message_file)['id']
    end
  end

  def test_private_checkpoint_choices_and_instructions_reach_the_reviewer
    with_trial do
      File.write(File.join(@root, CHOICES['prompt_file']), 'PRIVATE CHECKPOINT RULES')
      update_private { |data| data['review']['post_implementation'] = CHOICES }
      result = run_checkpoint
      assert_equal %w[completed anthropic/claude], result.values_at('status', 'reviewer')
      assert_equal 'Individual settings (private source)', result['prompt_source']
      assert_trace(['--model', 'claude-sonnet-4-6'], ['--effort', 'high'])
    end
  end

  private

  def record_on_pull(result)
    publish_delivery
    alter_pull { |pull| pull.merge!('comments' => [published(result)]).fetch('snapshot')['commits'] = COMMITS }
  end

  def assert_trace(*pairs)
    trace = JSON.parse(File.read(File.join(@state, 'checkpoint-trace.json')))
    pairs.each { |pair| assert_includes trace['args'].each_cons(2).to_a, pair }
    assert_includes trace['prompt'], 'PRIVATE CHECKPOINT RULES'
  end

  def run_checkpoint
    Dir.mktmpdir('checkpoint-cli', @state) do |bin|
      write_executable(bin, 'claude', checkpoint_reviewer)
      environment = { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}",
                      'REVIEW_TRACE' => File.join(@state, 'checkpoint-trace.json') }
      output, error, status = Open3.capture3(environment, COMMAND, 'post-implementation', 'run', '--root', @root,
                                             '--base', @ref, '--head', @ref, '--ref', @ref,
                                             '--content-file', state_file('packet.json', PACKET))
      assert_predicate status, :success?, "#{output}\n#{error}"
      JSON.parse(output)
    end
  end

  def checkpoint_reviewer
    report = { head: @ref, conclusion: 'Proceed', reasons: ['Useful change'], concerns: [],
               alternative: 'No change', summary: 'Evidence supports it.', next_action: 'Merge.' }
    <<~RUBY
      #!/usr/bin/env ruby
      require 'json'
      File.write(ENV.fetch('REVIEW_TRACE'), JSON.generate({ args: ARGV, prompt: STDIN.read }))
      puts JSON.generate(result: #{JSON.generate(report).dump})
    RUBY
  end

  # The fake API's comments carry no history fields, so publication exits 1 after posting the body.
  def published(result)
    output, error, status = Open3.capture3({ 'PATH' => "#{@state}:#{ENV.fetch('PATH')}", 'HOME' => @state },
                                           COMMAND, 'post-implementation', 'publish', 'owner/repo', '1',
                                           '--content-file', state_file('checkpoint.json', result))
    assert_equal 1, status.exitstatus, error
    { 'id' => 1, 'user' => { 'login' => 'shaka-agent' }, 'body' => JSON.parse(output).fetch('body') }
  end

  def message_file = state_file('message.json', 'title' => 'Fix', 'body' => 'Private delivery works.')

  def state_file(name, data)
    File.join(@state, name).tap { |path| File.write(path, JSON.generate(data)) }
  end
end
