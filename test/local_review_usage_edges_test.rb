# frozen_string_literal: true

require_relative 'local_review_usage_bridge_fixture'

class LocalReviewUsageEdgesTest < Minitest::Test
  include LocalReviewUsageBridgeFixture
  include LocalReviewCommentFixture

  COMMAND = LocalReviewCodexTest::COMMAND
  REVIEWERS = %w[anthropic/claude openai/codex].freeze
  MALFORMED = ['{"type":"result",', '{"type":"result","session_id":"review","usage":[]}',
               '{"type":"turn_context","payload":[]}', "not json\n"].freeze

  def test_mixed_legacy_prices_stay_estimates_and_missing_prices_are_partial
    with_captured_review do |ledger, result|
      content = triage_and_remove_source(ledger, result)
      legacy = { 'head' => 'b' * 40, 'reviewer' => 'openai/codex', 'report' => report('b' * 40, findings: 0),
                 'findings' => [], 'estimate' => '$0.02' }
      mixed = content.merge('rounds' => [legacy, *content['rounds']])
      assert_includes Shaka::LocalReviewComment.new(mixed).loop_summary, '$0.44 estimated'
      legacy.delete('estimate')
      assert_includes Shaka::LocalReviewComment.new(mixed).loop_summary, '$0.42+ estimated'
    end
  end

  def test_malformed_native_files_produce_unknown_metadata_instead_of_capture_errors
    Dir.mktmpdir do |directory|
      file = File.join(directory, 'native.json')
      MALFORMED.each do |native|
        File.write(file, native)
        REVIEWERS.each { |reviewer| assert_unknown_capture(file, reviewer) }
      end
    end
  end

  def test_runner_result_attaches_both_ledger_heads_after_source_cleanup
    with_repository do |root, base, head, bin|
      Dir.mktmpdir do |directory|
        ledger = File.join(directory, 'ledger.json')
        results = two_heads(root, base, head, bin, ledger)
        File.unlink(ledger)
        assert_attached_heads(results)
      end
    end
  end

  def test_older_saved_result_uses_its_ledger_then_its_own_record_if_the_ledger_is_missing
    with_captured_review do |ledger, result|
      triage_and_remove_source(ledger, result)
      legacy = result.except('usage_records')
      expected = [result.fetch('usage_record')]
      assert_equal expected, attached_description(legacy).dig('usage', 'records')
      File.unlink(ledger)
      assert_equal expected, attached_description(legacy).dig('usage', 'records')
    end
  end

  private

  def assert_attached_heads(results)
    records = attached_description(results.last).dig('usage', 'records')
    assert_equal 2, records.size
    assert_equal(results.map { |result| [result['head']] }, records.map { |record| record['commits'] })
  end

  def assert_unknown_capture(file, reviewer)
    record = Shaka::LocalReviewUsageCapture.capture('head' => 'a' * 40, 'reviewer' => reviewer, 'usage' => file)
    assert_equal 'UNKNOWN', record.dig('columns', 0, 'input')
    assert_equal 'cost UNKNOWN', Shaka::LocalReviewUsage.cost(record)
  end

  def two_heads(root, base, head, bin, ledger)
    results = []
    2.times do |index|
      results << run_native_round(root, base, head, bin, ledger)
      head = next_head(root) if index.zero?
    end
    results
  end

  def run_native_round(root, base, head, bin, ledger)
    fake_usage_cli(bin, head, 'anthropic/claude', {})
    out, err, status = run_review(root, base, head, bin, ledger:, reviewer: 'anthropic/claude')
    result = assert_successful_review(out, err, status, head, 'anthropic/claude')
    assert_equal File.realpath(ledger), result.fetch('ledger')
    triage_and_remove_source(ledger, result)
    result
  end

  def next_head(root)
    commit!(root, 'second', 'Second reviewed head')
    git!(root, 'rev-parse', 'HEAD').strip
  end
end

class LocalReviewUsageOverlapTest < Minitest::Test
  include LocalReviewUsageBridgeFixture

  COMMAND = LocalReviewCodexTest::COMMAND

  def test_a_copied_source_does_not_count_the_same_responses_twice
    with_captured_review do |ledger, result|
      triage_and_remove_source(ledger, result)
      copied = result.fetch('usage_record').merge('sources' => ['copied-source'])
      assert_single_record(result, copied)
    end
  end

  def test_a_missing_source_refresh_does_not_add_an_unknown_copy_or_erase_known_values
    with_captured_review do |ledger, result|
      triage_and_remove_source(ledger, result)
      unknown = Shaka::LocalReviewUsageCapture.capture(result)
      assert_equal 'UNKNOWN', unknown.dig('columns', 0, 'input')
      assert_single_record(result, unknown)
    end
  end

  def test_a_missing_source_refresh_preserves_recorded_cost_without_token_counters
    with_captured_review(native: { usage: {} }) do |ledger, result|
      triage_and_remove_source(ledger, result)
      assert_empty result.fetch('usage_record').fetch('responses')
      assert_single_record(result, Shaka::LocalReviewUsageCapture.capture(result))
    end
  end

  def test_known_cost_only_metadata_replaces_an_unreadable_capture
    with_captured_review(native: { usage: {} }) do |ledger, result|
      triage_and_remove_source(ledger, result)
      known = result.fetch('usage_record')
      empty = result.except('ledger').merge('usage_record' => Shaka::LocalReviewUsageCapture.capture(result))
      content = { 'usage' => { 'note' => '', 'records' => [known] } }
      assert_equal [known], attached_description(empty, content:).dig('usage', 'records')
    end
  end

  def test_known_attribution_survives_cleanup_without_counters_or_cost
    with_captured_review(native: { usage: {}, total_cost_usd: nil }) do |ledger, result|
      triage_and_remove_source(ledger, result)
      assert_single_record(result, Shaka::LocalReviewUsageCapture.capture(result), cost: 'cost UNKNOWN')
    end
  end

  private

  def assert_single_record(result, supplied, cost: '$0.42 estimated')
    content = { 'usage' => { 'note' => '', 'records' => [supplied] } }
    attached = attached_description(result, content:)
    assert_equal [result.fetch('usage_record')], attached.dig('usage', 'records')
    assert_equal cost, Shaka::LocalReviewUsage.cost(attached.dig('usage', 'records', 0))
  end
end

class LocalReviewUnknownUsageCopiesTest < Minitest::Test
  include LocalReviewUsageBridgeFixture

  COMMAND = LocalReviewCodexTest::COMMAND

  def test_unknown_incomplete_round_is_attached_once
    with_captured_review(reviewer: 'openai/codex') do |ledger, result|
      triage_and_remove_source(ledger, result)
      record = result.fetch('usage_record')
      refute record.fetch('complete')
      assert_equal 'UNKNOWN', record.dig('columns', 0, 'provider')
      assert_equal [record], attached_description(result).dig('usage', 'records')
    end
  end

  private

  def codex_records
    records = super
    conflict = records.last.merge(payload: records.last.fetch(:payload).merge(usage: {}))
    records + [conflict]
  end
end

class LocalReviewPartialUsageCopiesTest < Minitest::Test
  include LocalReviewUsageBridgeFixture

  COMMAND = LocalReviewCodexTest::COMMAND

  def test_incomplete_copied_snapshot_is_attached_once_but_distinct_coverage_survives
    with_captured_review(reviewer: 'openai/codex') do |ledger, result|
      triage_and_remove_source(ledger, result)
      record = result.fetch('usage_record')
      refute record.fetch('complete')
      assert_includes record.dig('columns', 0, 'usd'), '(partial)'
      copied = record.merge('sources' => ['copied-source'])
      content = { 'usage' => { 'note' => '', 'records' => [copied] } }
      assert_equal [record], attached_description(result, content:).dig('usage', 'records')
      assert_distinct_coverage(result, copied)
    end
  end

  private

  def assert_distinct_coverage(result, copied)
    distinct = copied.merge('responses' => ['different-response'])
    content = { 'usage' => { 'note' => '', 'records' => [distinct] } }
    assert_equal [result.fetch('usage_record'), distinct],
                 attached_description(result, content:).dig('usage', 'records')
  end

  def codex_records
    records = super
    unknown = records.last.merge(payload: records.last.fetch(:payload).merge(response_id: 'unreadable', usage: {}))
    records + [unknown]
  end
end
