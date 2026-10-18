# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'
require 'tmpdir'
require 'shaka/call_log'

class CallLogCommandsTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_recorded_commands_are_the_dispatched_commands
    # The usage banner lists every command the helper dispatches, from the same tables.
    output, error, status = Open3.capture3({ 'SHAKA_CALL_LOG' => 'off' }, COMMAND, '--help')
    assert_predicate status, :success?, error
    dispatched = output.scan(/^(?:Usage:)?\s+shaka \(?([a-z|-]+)/).flatten.flat_map { |names| names.split('|') }

    assert_equal dispatched.uniq.sort, Shaka::CallLog::COMMANDS
  end

  def test_guidance_calls_are_recorded_under_their_own_name
    Dir.mktmpdir do |directory|
      log = File.join(directory, 'calls.jsonl')
      Open3.capture3({ 'SHAKA_CALL_LOG' => log }, COMMAND, 'guidance', '--help')

      assert_equal(['guidance'], File.readlines(log).map { |line| JSON.parse(line).fetch('command') })
    end
  end
end
