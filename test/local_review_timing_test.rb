# frozen_string_literal: true

require_relative 'local_review_test'
require_relative 'local_review_batch_test'
require_relative 'openrouter_fixture'
require 'time'

module ReviewTimingAssertions
  private

  def assert_timing(result)
    assert_in_delta Time.now.to_f, Time.iso8601(result.fetch('started_at')).to_f, 10
    assert_kind_of Integer, result.fetch('duration_ms')
    assert_operator result.fetch('duration_ms'), :>=, 0
  end
end

module ReviewTimingFixture
  include LocalReviewFixture
  include ReviewTimingAssertions

  private

  def with_timed_review
    Dir.mktmpdir('shaka-timing-ledger') do |directory|
      with_repository { |root, base, head, bin| yield root, base, head, bin, File.join(directory, 'ledger.json') }
    end
  end

  def timed_run(*arguments, **options)
    path = arguments.pop
    expected = options.delete(:expected) || 'not_completed'
    output, error, status = run_review(*arguments, options.merge(ledger: path))
    result = JSON.parse(output)
    assert_equal expected, result.fetch('status'), error
    assert_equal expected == 'completed', status.success?, error
    assert_timing(result)
    result
  end

  def stored(path) = JSON.parse(File.read(path))

  def attempts(path) = File.readlines("#{path}.attempts.jsonl").map { |line| JSON.parse(line) }

  def assert_attempt(path, stage, attempted)
    assert_empty stored(path).fetch('rounds') if File.exist?(path)
    attempt = attempts(path).last
    assert_equal stage, attempt.fetch('failure_stage')
    assert_equal attempted, attempt.fetch('attempted')
  end
end

class LocalReviewTimingTest < Minitest::Test
  COMMAND = LocalReviewCodexTest::COMMAND
  include ReviewTimingFixture

  def test_completed_review_retains_attributable_timing_in_round_and_attempt
    with_timed_review do |root, base, head, bin, path|
      fake_codex(bin, head)
      result = timed_run(root, base, head, bin, path, expected: 'completed',
                                                      env: { 'REVIEW_TRACE' => File.join(bin, 'trace.json') })
      assert_completed_timing(result, stored(path), attempts(path))
    ensure
      cleanup_artifacts(result)
    end
  end

  def test_cli_failure_and_retry_remain_separate_attempts_without_completed_rounds
    with_timed_review do |root, base, head, bin, path|
      write_executable(bin, 'codex', "#!/bin/sh\necho private-diagnostic >&2\nexit 42\n")
      2.times { cleanup_artifacts(timed_run(root, base, head, bin, path)) }
      assert_attempt(path, 'cli_failure', true)
      assert_equal 2, attempts(path).size
      refute_includes File.read("#{path}.attempts.jsonl"), 'private-diagnostic'
      refute_includes File.read("#{path}.attempts.jsonl"), 'diagnostic_path'
    end
  end

  def test_timeout_keeps_actual_elapsed_time_and_deadline_without_a_round
    with_timed_review do |root, base, head, bin, path|
      write_executable(bin, 'codex', "#!/bin/sh\nsleep 10\n")
      result = timed_run(root, base, head, bin, path, timeout_seconds: 1)
      assert_timeout_timing(result, path)
    ensure
      cleanup_artifacts(result)
    end
  end

  def test_setup_failure_is_timed_and_retained_before_ledger_round_start
    with_timed_review do |root, base, _head, bin, path|
      timed_run(root, base, base, bin, path)
      assert_attempt(path, 'setup_failure', false)
    end
  end

  def test_invalid_report_is_timed_without_gaining_completed_review_evidence
    with_timed_review do |root, base, head, bin, path|
      fake_unattested_codex(bin)
      result = timed_run(root, base, head, bin, path)
      assert_attempt(path, 'report_validation', true)
    ensure
      cleanup_artifacts(result)
    end
  end

  def test_missing_cli_is_timed_and_retained_without_claiming_invocation
    with_timed_review do |root, base, head, bin, path|
      File.symlink(RbConfig.ruby, File.join(bin, 'ruby'))
      File.symlink(TEST_GIT, File.join(bin, 'git'))
      timed_run(root, base, head, bin, path, env: { 'PATH' => bin })
      assert_attempt(path, 'executable_missing', false)
    end
  end

  def test_unsafe_ledger_reports_retention_gap_and_returns_timing
    with_timed_review do |root, base, head, bin, _path|
      path = File.join(root, 'ledger.json')
      result = timed_run(root, base, head, bin, path)
      assert_equal 'not_retained', result.fetch('timing_retention')
      assert_includes result.fetch('timing_retention_reason'), 'outside the candidate checkout'
      refute_path_exists path
    end
  end

  private

  def assert_completed_timing(result, saved, attempts)
    timing = result.slice('started_at', 'duration_ms')
    assert_equal timing, saved.fetch('rounds').first.slice(*timing.keys)
    attempt = attempts.first
    assert_equal timing, attempt.slice(*timing.keys)
    assert_equal result.values_at('head', 'reviewer', 'status'), attempt.values_at('head', 'reviewer', 'status')
    assert attempt.fetch('attempted')
  end

  def assert_timeout_timing(result, path)
    assert_operator result.fetch('duration_ms'), :>=, 1000
    assert_operator result.fetch('duration_ms'), :<, 6000
    assert_equal 1, result.fetch('timeout_seconds')
    assert_attempt(path, 'cli_failure', true)
    assert_equal 1, attempts(path).first.fetch('timeout_seconds')
  end
end

class OpenrouterTimingTest < Minitest::Test
  include OpenrouterFixture
  include ReviewTimingAssertions

  def test_api_completion_and_timeout_both_return_timing
    with_review_repository do |root, base, head|
      [->(*) { completion(head) }, ->(*) { raise Timeout::Error }].each do |request|
        with_key { with_request(request) { assert_api_timing(root, base, head) } }
      end
    end
  end

  def test_missing_key_returns_timing_without_invoking_api
    with_review_repository do |root, base, head|
      with_key('') do
        with_request(->(*) { flunk 'missing credentials must not launch a request' }) do
          assert_api_timing(root, base, head)
        end
      end
    end
  end

  private

  def assert_api_timing(root, base, head)
    result = Shaka::LocalReviewRunner.new(root:, base:, head:, reviewer: 'deepseek/openrouter',
                                          model: MODEL, effort: 'high', timeout_seconds: 1).run
    assert_timing(result)
    assert_equal 1, result.fetch('timeout_seconds')
  ensure
    %w[report usage].each { |key| FileUtils.rm_f(result[key]) if result && result[key] }
  end
end

class ReviewTimingLedgerConcurrencyTest < Minitest::Test
  include LocalReviewLedgerSteps

  def test_parallel_terminal_attempt_writes_preserve_old_rounds_and_every_attempt
    append(EARLIER, 'openai/codex', findings: 0)
    parallel_attempts
    saved = JSON.parse(File.read(@path))
    assert_equal 1, saved.fetch('rounds').size
    assert_equal %w[openai/codex anthropic/claude].sort, attempt_reviewers.sort
    assert_equal [1], ledger.record!({ 'findings' => [] })
  end

  private

  def attempt_reviewers
    File.readlines("#{@path}.attempts.jsonl").map { |line| JSON.parse(line)['reviewer'] }
  end

  def parallel_attempts
    [ledger, ledger].zip(%w[openai/codex anthropic/claude]).map do |reader, reviewer|
      reader.rounds
      Thread.new do
        reader.record_attempt!('head' => HEAD, 'reviewer' => reviewer, 'status' => 'not_completed',
                               'attempted' => true, 'failure_stage' => 'cli_failure',
                               'started_at' => Time.now.utc.iso8601, 'duration_ms' => 1000)
      end
    end.each(&:value)
  end
end

class LocalReviewTimingRecoveryTest < Minitest::Test
  COMMAND = LocalReviewCodexTest::COMMAND
  include ReviewTimingFixture

  def test_refused_start_keeps_existing_history_and_retains_timing
    with_timed_review do |root, base, head, bin, path|
      fake_codex(bin, head)
      cleanup_artifacts(timed_run(root, base, head, bin, path, expected: 'completed',
                                                               env: { 'REVIEW_TRACE' => File.join(bin, 'trace.json') }))
      original = File.read(path)
      result = timed_run(root, base, base, bin, path)
      assert_equal 'retained', result.fetch('timing_retention')
      assert_equal 2, attempts(path).size
      assert_equal original, File.read(path)
    end
  end

  def test_malformed_ledger_returns_timing_and_keeps_original_bytes
    with_timed_review do |root, base, head, bin, path|
      File.write(path, '{invalid')
      result = timed_run(root, base, head, bin, path)
      assert_equal 'setup_failure', result.fetch('failure_stage')
      assert_equal 'retained', result.fetch('timing_retention')
      assert_equal '{invalid', File.read(path)
    end
  end

  def test_repeated_pre_start_failures_then_success_keep_every_attempt
    with_timed_review do |root, base, head, bin, path|
      2.times { timed_run(root, base, base, bin, path) }
      refute_path_exists path
      fake_codex(bin, head)
      result = timed_run(root, base, head, bin, path, expected: 'completed',
                                                      env: { 'REVIEW_TRACE' => File.join(bin, 'trace.json') })
      assert_equal(%w[not_completed not_completed completed], attempts(path).map { |a| a['status'] })
    ensure
      cleanup_artifacts(result)
    end
  end

  def test_corruption_during_review_returns_timing_without_rewriting_history
    with_timed_review do |root, base, head, bin, path|
      corrupting_codex(bin, head, path)
      result = timed_run(root, base, head, bin, path)
      assert_equal 'setup_failure', result.fetch('failure_stage')
      assert_equal '{invalid', File.read(path)
      assert_equal 'not_completed', attempts(path).last.fetch('status')
    end
  end

  private

  def corrupting_codex(bin, head, path)
    write_executable(bin, 'codex', <<~RUBY_SCRIPT)
      #!/usr/bin/env ruby
      File.write(#{path.inspect}, '{invalid')
      File.write(ARGV.fetch(ARGV.index('-o') + 1), "REVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\n")
    RUBY_SCRIPT
  end
end

class LocalReviewTimingInputTest < Minitest::Test
  include ReviewTimingFixture

  def test_rejected_integer_deadlines_are_not_returned_or_retained
    with_timed_review do |root, base, head, _bin, path|
      [0, 3601].each do |deadline|
        result = input_run(root, base, head, path, timeout_seconds: deadline)
        assert_setup_timing(result)
        refute result.key?('timeout_seconds')
        refute attempts(path).last.key?('timeout_seconds')
      end
      assert_equal 2, attempts(path).size
      refute_path_exists path
    end
  end

  def test_early_validation_failure_does_not_claim_an_unvalidated_deadline
    with_timed_review do |root, base, head, _bin, path|
      result = input_run(root, base, head, path, base: 'invalid', timeout_seconds: 1)
      assert_setup_timing(result)
      refute result.key?('timeout_seconds')
      refute attempts(path).last.key?('timeout_seconds')
    end
  end

  def test_invalid_root_after_early_failure_preserves_timing_with_a_retention_gap
    with_timed_review do |root, base, head, _bin, path|
      [nil, "\0"].each do |invalid_root|
        result = input_run(root, base, head, path, root: invalid_root, max_review_executions: 0)
        assert_setup_timing(result)
        assert_equal 'not_retained', result.fetch('timing_retention')
        refute_empty result.fetch('timing_retention_reason')
        refute_path_exists path
        refute_path_exists "#{path}.attempts.jsonl"
      end
    end
  end

  private

  def input_run(root, base, head, path, **overrides)
    options = { root:, base:, head:, reviewer: 'openai/codex', ledger: path }.merge(overrides)
    Shaka::LocalReviewRunner.new(options).run
  end

  def assert_setup_timing(result)
    assert_equal 'not_completed', result.fetch('status')
    assert_equal 'setup_failure', result.fetch('failure_stage')
    refute result.fetch('attempted')
    assert_timing(result)
  end
end
