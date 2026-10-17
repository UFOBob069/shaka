# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../eval/lib/shaka/evaluation/native_usage'
require_relative 'support/evaluation_native_fixture'

class EvaluationNativeAccountingTest < Minitest::Test
  include EvaluationNativeFixture

  def setup
    @directory = Dir.mktmpdir
    setup_native_reader
  end

  def teardown = FileUtils.remove_entry(@directory)

  def test_codex_preserves_categories_and_unknown_route_without_double_counting
    result = capture('codex', codex_rows)
    model = result['models'].first
    expected = { 'input_tokens' => 100_000, 'cached_input_tokens' => 80_000, 'output_tokens' => 1000,
                 'reasoning_tokens' => 200, 'routed_model' => 'UNKNOWN' }
    assert_equal expected, model.slice(*expected.keys)
    assert_costs result, neutral: 0.21, billed: 0.058
  end

  def test_claude_normalizes_exclusive_input_and_preserves_output_subsets
    result = capture('claude-code', claude_rows)
    model = result['models'].first
    expected = { 'input_tokens' => 100_000, 'cache_write_tokens' => 10_000, 'reasoning_tokens' => 200,
                 'configured_model' => 'UNKNOWN', 'routed_model' => 'claude-sonnet-5' }
    assert_equal expected, model.slice(*expected.keys)
    assert_costs result, neutral: 0.21, billed: 0.071
  end

  def test_repricing_preserves_request_context
    result = capture('codex', codex_rows(input: 300_000))
    assert_in_delta 1.215, result['cache_neutral_dollars'], 0.000001
  end

  def test_native_billed_cost_cannot_override_cache_neutral_repricing
    rows = codex_rows
    rows.last['payload']['usage']['native_cost_usd'] = 0.001
    assert_costs capture('codex', rows), neutral: 0.21, billed: 0.001
  end

  def test_repricing_preserves_speed_geography_and_server_fees
    rows = claude_rows
    rows.last['message']['model'] = 'claude-opus-5-5'
    rows.last['message']['usage'].merge!('speed' => 'fast', 'inference_geo' => 'us',
                                         'server_tool_use' => { 'web_search_requests' => 2 })
    result = capture('claude-code', rows)
    assert_in_delta 0.944, result['cache_neutral_dollars'], 0.000001
    assert_equal 'claude-opus-5-5', result['models'].first['routed_model']
  end

  def test_missing_unknown_and_inconsistent_evidence_never_prices_as_zero
    { 'output_tokens' => nil, 'cached_input_tokens' => 100_001, 'input_tokens' => -1 }.each do |field, value|
      rows = codex_rows
      rows.last['payload']['usage'][field] = value
      assert_equal 'UNKNOWN', capture('codex', rows)['cache_neutral_dollars']
    end
  end

  def test_unpriced_model_is_unknown
    rows = codex_rows
    rows[1]['payload']['model'] = 'not-priced'
    assert_equal 'UNKNOWN', capture('codex', rows)['cache_neutral_dollars']
  end

  def test_conflicting_response_copies_are_unknown
    rows = codex_rows
    rows << rows.last.merge('payload' => rows.last['payload'].merge('usage' => {}))
    assert_equal 'UNKNOWN', capture('codex', rows)['cache_neutral_dollars']
  end

  def test_a_dropped_paid_response_cannot_hide_behind_a_complete_report
    rows = claude_rows
    rows.unshift(rows.last.merge('message' => rows.last['message'].merge('id' => 'missing-turn')))
    assert_equal 'UNKNOWN', capture('claude-code', rows)['cache_neutral_dollars']
  end

  def test_unidentified_paid_response_is_unknown
    rows = codex_rows
    rows.last['payload'].delete('response_id')
    assert_equal 'UNKNOWN', capture('codex', rows)['cache_neutral_dollars']
  end

  def test_duplicate_session_copies_count_once_and_empty_or_malformed_sources_are_unknown
    capture('codex', codex_rows)
    path = File.join(@directory, 'session.jsonl')
    FileUtils.cp(path, File.join(@directory, 'copy.jsonl'))
    result = @reader.read(host: 'codex', files: [path, File.join(@directory, 'copy.jsonl')])
    assert_in_delta 0.21, result['cache_neutral_dollars'], 0.000001
  end

  def test_empty_or_malformed_sources_are_unknown
    path = File.join(@directory, 'session.jsonl')
    ['', '{bad', '{}', '{"type":"result"}'].each do |source|
      File.write(path, source)
      result = @reader.read(host: 'codex', files: [path])
      assert_equal 'UNKNOWN', result['cache_neutral_dollars']
      refute_includes JSON.generate(result), @directory
    end
  end
end
