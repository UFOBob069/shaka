# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/usage/publisher_attribution'

module PublisherAttributionFixture
  ID = '11111111-1111-1111-1111-111111111111'

  def with_session(*records)
    Dir.mktmpdir do |home|
      directory = File.join(home, 'sessions', '2026', '10', '05')
      FileUtils.mkdir_p(directory)
      file = File.join(directory, "rollout-#{ID}.jsonl")
      metadata = { 'type' => 'session_meta', 'payload' => { 'id' => ID, 'model_provider' => 'openai' } }
      File.write(file, "#{([metadata] + records).map { |record| JSON.generate(record) }.join("\n")}\n")
      environment = { 'CODEX_HOME' => home, 'CODEX_THREAD_ID' => ID }
      yield environment, file
    end
  end

  def context(model = 'gpt-6.1-sol', effort = 'medium')
    { 'type' => 'turn_context', 'payload' => { 'turn_id' => 'current', 'model' => model, 'effort' => effort } }
  end

  def content
    { 'identity' => { 'agent' => 'Codex', 'provider' => 'OpenAI', 'model' => 'UNKNOWN', 'effort' => 'UNKNOWN' },
      'provenance' => { 'active_model' => 'UNKNOWN', 'active_effort' => 'UNKNOWN' },
      'usage' => { 'records' => [{ 'columns' => [{ 'model' => 'reviewer-model', 'effort' => 'high' }] }] } }
  end
end

class PublisherAttributionTest < Minitest::Test
  include PublisherAttributionFixture

  def test_unknown_fields_are_filled_from_latest_context_without_usage
    with_session(context('older', 'low'), context) do |environment, _file|
      result = Shaka::PublisherAttribution.prepare(content, environment:)
      assert_equal 'gpt-6.1-sol (configured)', result.dig('identity', 'model')
      assert_equal 'medium', result.dig('identity', 'effort')
      assert_equal 'gpt-6.1-sol', result.dig('provenance', 'active_model')
      assert_equal 'medium', result.dig('provenance', 'active_effort')
      assert_includes result['publisher_note'], 'served model is UNKNOWN'
    end
  end

  def test_reviewer_records_do_not_supply_publisher_settings
    with_session(context) do |environment, _file|
      result = Shaka::PublisherAttribution.prepare(content, environment:)
      assert_equal content['usage'], result['usage']
    end
  end

  def test_concrete_conflicts_in_either_identity_or_provenance_are_refused
    with_session(context) do |environment, _file|
      [%w[identity model], %w[provenance active_model], %w[identity effort]].each do |section, field|
        supplied = content
        supplied[section][field] = 'wrong'
        error = assert_raises(Shaka::Error) { Shaka::PublisherAttribution.prepare(supplied, environment:) }
        assert_includes error.message, 'conflicts with native publisher settings'
      end
    end
  end

  def test_unreadable_tail_does_not_reuse_old_settings
    with_session(context) do |environment, file|
      File.write(file, '{broken', mode: 'a')
      result = Shaka::PublisherAttribution.prepare(content, environment:)
      assert_equal 'UNKNOWN', result.dig('identity', 'model')
      assert_includes result['publisher_note'], 'unreadable'
    end
  end

  def test_invalid_utf8_is_unknown_instead_of_raising
    with_session(context) do |environment, file|
      line = JSON.generate(context('broken-byte'))
      File.binwrite(file, "#{line.sub('broken-byte', "\xFF")}\n", mode: 'a')
      result = Shaka::PublisherAttribution.prepare(content, environment:)
      assert_equal 'UNKNOWN', result.dig('identity', 'model')
      assert_includes result['publisher_note'], 'unreadable'
    end
  end

  def test_new_turn_without_context_does_not_inherit_previous_turn
    started = { 'type' => 'event_msg', 'payload' => { 'type' => 'task_started', 'turn_id' => 'new' } }
    with_session(context, started) do |environment, _file|
      result = Shaka::PublisherAttribution.prepare(content, environment:)
      assert_equal 'UNKNOWN', result.dig('identity', 'effort')
      assert_includes result['publisher_note'], 'current turn'
    end
  end

  def test_missing_source_explains_unknown_and_does_not_trust_usage
    result = Shaka::PublisherAttribution.prepare(content,
                                                 environment: { 'CODEX_THREAD_ID' => ID, 'CODEX_HOME' => '/missing' })
    assert_equal 'UNKNOWN', result.dig('identity', 'model')
    assert_includes result['publisher_note'], 'session unavailable or ambiguous'
  end

  def test_stale_context_after_new_turn_is_not_used
    started = { 'type' => 'event_msg', 'payload' => { 'type' => 'task_started', 'turn_id' => 'new' } }
    with_session(context, started, context) do |environment, _file|
      result = Shaka::PublisherAttribution.prepare(content, environment:)
      assert_equal 'UNKNOWN', result.dig('identity', 'model')
    end
  end

  def test_partial_context_keeps_known_model_without_inventing_effort
    with_session(context('gpt-test', nil)) do |environment, _file|
      result = Shaka::PublisherAttribution.prepare(content, environment:)
      assert_equal 'gpt-test (configured)', result.dig('identity', 'model')
      assert_equal 'UNKNOWN', result.dig('provenance', 'active_effort')
      assert_includes result['publisher_note'], 'UNKNOWN effort'
    end
  end

  def test_ambiguous_source_is_unknown
    with_session(context) do |environment, file|
      FileUtils.cp(file, File.join(File.dirname(file), "duplicate-#{ID}.jsonl"))
      result = Shaka::PublisherAttribution.prepare(content, environment:)
      assert_equal 'UNKNOWN', result.dig('identity', 'model')
      assert_includes result['publisher_note'], 'ambiguous'
    end
  end

  def test_other_hosts_preserve_supplied_attribution_with_explicit_evidence_gap
    result = Shaka::PublisherAttribution.prepare(content, environment: { 'CURSOR_CONVERSATION_ID' => 'session' })
    assert_equal content['identity'], result['identity']
    assert_includes result['publisher_note'], 'Native publisher settings unavailable'
  end
end
