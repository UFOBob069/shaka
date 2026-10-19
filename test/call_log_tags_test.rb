# frozen_string_literal: true

require_relative 'support/post_implementation_fixture'
require 'shaka/call_log'

# Records name the task, head, and reviewer settings a command was given, and nothing else.
class CallLogTagsTest < Minitest::Test
  include PostImplementationFixture

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  HEAD = 'a' * 40

  def test_pull_request_commands_record_repository_number_and_head
    with_log do |log, env|
      call(env, 'pr', 'acme/widgets', '12', '--head', HEAD)
      call(env, 'pr', 'watch', '--head', HEAD, '--ref', HEAD, 'acme/widgets', '13')

      assert_equal([['acme/widgets', 12, HEAD], ['acme/widgets', 13, HEAD]], records(log).map { |record| tags(record) })
    end
  end

  def test_commands_that_open_a_pull_request_record_its_repository_and_number
    with_log do |log, env|
      call(env, 'review', 'publish', 'acme/widgets', '9', '--content-file', File.join(Dir.tmpdir, 'missing.json'))

      assert_equal ['acme/widgets', 9, nil], tags(records(log).fetch(0))
    end
  end

  def test_a_second_pull_request_read_keeps_the_first_one
    before = Shaka::CallLog.tags.dup
    Shaka::CallLog.first_tag(repository: 'acme/widgets', number: 1)
    Shaka::CallLog.first_tag(repository: 'acme/other', number: 2)
    assert_equal ['acme/widgets', 1], Shaka::CallLog.tags.values_at('repository', 'number')
  ensure
    Shaka::CallLog.tags.replace(before)
  end

  def test_evidence_commands_record_repository_and_head
    with_log do |log, env|
      call(env, 'evidence', 'guard', '--root', Dir.pwd, '--ref', HEAD, '--repository', 'acme/widgets',
           '--base', 'main', '--head', HEAD)

      assert_equal ['acme/widgets', nil, HEAD], tags(records(log).fetch(0))
    end
  end

  def test_claim_records_only_a_github_number
    with_log do |log, env|
      call(env, 'claim', '712')
      call(env, 'claim', 'ENG-123')
      call(env, 'claim', '--description', 'private-slug')

      assert_equal([712, nil, nil], records(log).map { |record| record['number'] })
      refute_includes File.read(log), 'ENG-123'
    end
  end

  def test_values_without_their_shape_are_left_out
    with_log do |log, env|
      call(env, 'pr', 'acme/widgets;private', '12x', '--head', 'private-head')
      call(env, 'review', 'run', '--root', Dir.pwd, '--base', HEAD, '--head', HEAD, '--reviewer', 'openai/codex',
           '--model', 'private model', '--effort', 'Private!')

      first, second = records(log)
      assert_equal [nil, nil, nil], tags(first)
      assert_equal %w[openai], second.values_at('provider', 'model', 'effort').compact
      refute_includes File.read(log), 'private'
      refute_includes File.read(log), 'Private'
    end
  end

  def test_review_run_records_its_reviewer_settings_even_when_it_fails
    with_log do |log, env|
      _, status = call(env, 'review', 'run', '--root', Dir.pwd, '--base', HEAD, '--head', HEAD, '--reviewer',
                       'anthropic/claude', '--model', 'claude-opus-5-5', '--effort', 'high')
      refute_predicate status, :success?

      record = records(log).fetch(0)
      assert_equal ['review run', HEAD, 'anthropic', 'claude-opus-5-5', 'high', status.exitstatus],
                   record.values_at('command', 'head', 'provider', 'model', 'effort', 'exit')
    end
  end

  def test_checkpoint_run_records_the_settings_it_resolved_from_trusted_configuration
    settings = { 'post_implementation' => { 'model' => 'chosen-model', 'effort' => 'high' } }
    with_repository(settings) do |root, base, head, bin|
      fake_checkpoint(bin, head)
      log = File.join(root, 'calls.jsonl')
      _, status = run_checkpoint(root, base, head, bin, { 'SHAKA_CALL_LOG' => log })
      assert_predicate status, :success?

      assert_equal ['post-implementation run', head, 'openai', 'chosen-model', 'high'],
                   records(log).fetch(0).values_at('command', 'head', 'provider', 'model', 'effort')
    end
  end

  def test_tag_drops_unknown_keys_long_values_and_invalid_text
    before = Shaka::CallLog.tags.dup
    Shaka::CallLog.tag(task: 'private', model: "m#{'x' * 100}", effort: "hi\xFFgh", provider: :openai, number: nil)
    assert_equal before, Shaka::CallLog.tags
  end

  private

  def call(env, *)
    output, status = Open3.capture2e(env, COMMAND, *)
    [output, status]
  end

  def tags(record) = record.values_at('repository', 'number', 'head')

  # A failing gh keeps commands that would read GitHub off the network.
  def with_log
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'gh'), "#!/bin/sh\nexit 1\n")
      File.chmod(0o700, File.join(directory, 'gh'))
      log = File.join(directory, 'calls.jsonl')
      yield log, { 'SHAKA_CALL_LOG' => log, 'PATH' => "#{directory}:#{ENV.fetch('PATH')}" }
    end
  end

  def records(log) = File.readlines(log).map { |line| JSON.parse(line) }
end
