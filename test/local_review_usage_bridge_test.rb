# frozen_string_literal: true

require_relative 'local_review_usage_bridge_fixture'

class LocalReviewUsageBridgeTest < Minitest::Test
  include LocalReviewUsageBridgeFixture

  COMMAND = LocalReviewCodexTest::COMMAND

  def test_native_counters_survive_runner_triage_cleanup_and_publication
    with_captured_review do |ledger, result|
      content = triage_and_remove_source(ledger, result)
      body = publish_twice(content)
      assert_claude_counters(body)
      assert_safe_publication(body, result)
      assert_equal "REVIEWED #{result['head']} BY anthropic/claude EFFORT medium FINDINGS 0", body.lines.last.strip
    end
  end

  def test_description_automatically_reuses_ledger_records_and_republishes_once
    with_captured_review do |ledger, result|
      triage_and_remove_source(ledger, result)
      attached = attached_description(result)
      assert_equal 1, attached.dig('usage', 'records').size
      assert_description_republish(attached)
      refute_includes attached.to_json, result.fetch('usage')
    end
  end

  def test_codex_inclusive_input_is_kept_without_inventing_a_native_total
    with_captured_review(reviewer: 'openai/codex') do |ledger, result|
      content = triage_and_remove_source(ledger, result)
      assert_codex_counters(content.dig('rounds', 0, 'usage_record'))
      assert_includes Shaka::LocalReviewComment.new(content).loop_summary, 'totals not combined'
      body = publish_twice(content)
      assert_includes body, '158,831 input<br>134,528 cached input<br>0 cache writes<br>1,265 output'
      refute_includes body, '160,096 tokens'
    end
  end

  def test_shared_model_and_partial_usage_survive_triage_without_a_made_up_price
    with_captured_review(native: shared_partial_native) do |ledger, result|
      content = triage_and_remove_source(ledger, result)
      Shaka::LocalReviewLedger.new(ledger).record!({})
      assert_equal content, JSON.parse(File.read(ledger))
      assert_shared_partial(content)
    end
  end

  def test_missing_source_is_unknown_and_legacy_scalar_publication_still_works
    with_captured_review(reviewer: 'openai/codex', missing: true) do |ledger, result|
      refute result.key?('usage_record')
      content = triage_and_remove_source(ledger, result, { 'findings' => [], 'tokens' => '500', 'estimate' => '$0.02' })
      summary = Shaka::LocalReviewComment.new(content).loop_summary
      assert_includes summary, '500 tokens'
      assert_includes summary, '$0.02 API-equivalent estimate'
    end
  end

  private

  def assert_claude_counters(body)
    ['6 input', '78,309 cached input', '26,042 cache writes', '4,521 output', '$0.42 estimated'].each do |text|
      assert_includes body, text
    end
  end

  def assert_safe_publication(body, result)
    refute_includes body, result.fetch('usage')
    refute_includes body, 'PRIVATE TRANSCRIPT'
    refute_includes result.fetch('usage_record').to_json, 'PRIVATE TRANSCRIPT'
  end

  def assert_codex_counters(record)
    assert_equal '158831', record.dig('columns', 0, 'input')
    assert_equal '134528', record.dig('columns', 0, 'cached_input')
    assert_equal '0', record.dig('columns', 0, 'cache_writes')
  end

  def assert_shared_partial(content)
    round = content.fetch('rounds').first
    assert_equal 'shared: claude-opus-5-5, claude-sonnet-4-5', round['model']
    assert_equal 'UNKNOWN', round.dig('usage_record', 'columns', 0, 'routed')
    body = publish_twice(content)
    assert_includes body, '6 input<br>UNKNOWN cached input<br>26,042 cache writes<br>4,521 output'
    assert_includes body, 'cost UNKNOWN'
  end

  def assert_description_republish(attached)
    first = Shaka::UsageDetails.new(attached.fetch('usage')).detail
    pull = { 'body' => "<!-- shaka:begin -->\n#{first['body']}\n<!-- shaka:end -->",
             'head' => { 'repo' => { 'full_name' => 'o/r' } }, 'base' => { 'repo' => { 'full_name' => 'o/r' } } }
    carried, = Shaka::UsageRecords.carry_from(attached, pull)
    assert_equal first, Shaka::UsageDetails.new(carried.fetch('usage')).detail
  end
end
