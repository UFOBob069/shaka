# frozen_string_literal: true

require_relative 'test_helper'
require 'json'

class EvaluationRunRecordCliTest < Minitest::Test
  FIXTURE = File.expand_path('fixtures/evaluation-run-record.json', __dir__)
  CLI = File.expand_path('../eval/bin/shaka-eval', __dir__)

  def test_valid_shape_emits_no_release_verdict_or_private_values
    output, _error, status = Open3.capture3('ruby', CLI, 'check-record', FIXTURE)
    assert_predicate status, :success?
    assert_equal({ 'valid' => true, 'errors' => [] }, JSON.parse(output))
  end

  def test_invalid_json_does_not_echo_its_contents
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'record.json')
      File.write(path, '{"private-value":')
      output, _error, status = Open3.capture3('ruby', CLI, 'check-record', path)
      assert_equal 1, status.exitstatus
      assert_equal({ 'valid' => false, 'errors' => ['Invalid JSON'] }, JSON.parse(output))
      refute_includes output, 'private-value'
    end
  end

  def test_unreadable_input_and_wrong_arguments
    output, _error, status = Open3.capture3('ruby', CLI, 'check-record', '/no-such-private-record.json')
    assert_equal 1, status.exitstatus
    assert_equal({ 'valid' => false, 'errors' => ['Cannot read record'] }, JSON.parse(output))
    _output, error, status = Open3.capture3('ruby', CLI, 'run')
    assert_equal 2, status.exitstatus
    assert_includes error, 'Usage:'
  end

  def test_invalid_utf8_returns_a_private_safe_error
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'record.json')
      File.binwrite(path, File.read(FIXTURE).sub("sha256:#{'a' * 64}", "\xFF".b))
      output, error, status = Open3.capture3('ruby', CLI, 'check-record', path)
      assert_equal 1, status.exitstatus
      assert_equal({ 'valid' => false, 'errors' => ['Invalid JSON'] }, JSON.parse(output))
      assert_empty error
    end
  end
end
