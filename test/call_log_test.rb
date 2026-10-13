# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'time'

class CallLogTest < Minitest::Test
  include EvidenceFixture

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_successful_call_appends_one_timed_record
    with_log do |log|
      _output, error, status = Open3.capture3({ 'SHAKA_CALL_LOG' => log }, COMMAND, 'workflow', '--help')
      assert_predicate status, :success?, error

      assert_equal 1, records(log).length
      assert_timed records(log).fetch(0), 'at'
      assert_equal ['workflow', 0], records(log).fetch(0).values_at('command', 'exit')
    end
  end

  def test_later_calls_append_to_the_same_file
    with_log do |log|
      2.times { Open3.capture3({ 'SHAKA_CALL_LOG' => log }, COMMAND, 'workflow', '--help') }
      assert_equal 2, records(log).length
    end
  end

  def test_failed_call_records_its_exit_status_without_its_arguments
    with_log do |log|
      _output, _error, status = Open3.capture3({ 'SHAKA_CALL_LOG' => log }, COMMAND, 'claim', 'private-query')
      refute_predicate status, :success?

      assert_equal ['claim', status.exitstatus], records(log).fetch(0).values_at('command', 'exit')
      refute_includes File.read(log), 'private-query'
    end
  end

  def test_subcommand_and_fixed_check_name_are_recorded
    with_log do |log|
      Open3.capture3({ 'SHAKA_CALL_LOG' => log }, COMMAND, 'evidence', 'run', '--command', 'validate', '--help')
      Open3.capture3({ 'SHAKA_CALL_LOG' => log }, COMMAND, 'evidence', 'run', '--command', 'private-name', '--help')

      first, second = records(log)
      assert_equal ['evidence run', 'validate'], first.values_at('command', 'check')
      refute second.key?('check')
      refute_includes File.read(log), 'private-name'
    end
  end

  def test_words_outside_the_known_commands_are_not_recorded
    with_log do |log|
      Open3.capture3({ 'SHAKA_CALL_LOG' => log }, COMMAND, 'pr', 'confidential', '1')
      Open3.capture3({ 'SHAKA_CALL_LOG' => log }, COMMAND, 'confidential')

      assert_equal(%w[pr unknown], records(log).map { |record| record.fetch('command') })
      refute_includes File.read(log), 'confidential'
    end
  end

  def test_recorded_check_names_are_the_fixed_evidence_commands
    assert_equal Shaka::Evidence::Command::NAMES, Shaka::CallLog::CHECKS
  end

  def test_default_location_is_the_state_directory_under_home
    Dir.mktmpdir do |home|
      Open3.capture3({ 'HOME' => home, 'SHAKA_CALL_LOG' => nil }, COMMAND, 'workflow', '--help')
      log = File.join(home, '.local/state/shaka/calls.jsonl')
      assert_equal 1, records(log).length
      assert_equal 0o600, File.stat(log).mode & 0o777
    end
  end

  def test_off_records_nothing
    Dir.mktmpdir do |home|
      Open3.capture3({ 'HOME' => home, 'SHAKA_CALL_LOG' => 'off' }, COMMAND, 'workflow', '--help')
      assert_empty Dir.children(home)
    end
  end

  def test_unwritable_log_warns_and_leaves_the_exit_status_alone
    Dir.mktmpdir do |directory|
      blocker = File.join(directory, 'file')
      File.write(blocker, '')
      env = { 'SHAKA_CALL_LOG' => File.join(blocker, 'calls.jsonl') }
      output, error, status = Open3.capture3(env, COMMAND, 'workflow', '--help')
      assert_predicate status, :success?
      assert_includes output, 'Usage: shaka workflow'
      assert_includes error, 'shaka: call log not written'
      assert_equal 1, Open3.capture3(env, COMMAND, 'claim', 'query').last.exitstatus
    end
  end

  def test_evidence_run_result_reports_when_and_how_long_the_check_ran
    with_checkout do |root, ref|
      assert_timed run_check(root, ref), 'started_at'
    end
  end

  private

  def assert_timed(record, start_key)
    assert_kind_of Integer, record.fetch('duration_ms')
    assert_in_delta Time.now.to_f, Time.iso8601(record.fetch(start_key)).to_f, 60
  end

  def with_log
    Dir.mktmpdir { |directory| yield File.join(directory, 'nested', 'calls.jsonl') }
  end

  def records(log) = File.readlines(log).map { |line| JSON.parse(line) }
end
