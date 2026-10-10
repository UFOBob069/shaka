# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/usage/publisher_attribution'

module ClaudePublisherAttributionFixture
  CLAUDE_ID = '22222222-2222-2222-2222-222222222222'

  def with_claude_session(*records, project: 'project')
    Dir.mktmpdir do |home|
      file = File.join(home, 'projects', project, "#{CLAUDE_ID}.jsonl")
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, "#{records.map { |record| JSON.generate(record) }.join("\n")}\n")
      yield({ 'CLAUDE_CONFIG_DIR' => home, 'CLAUDE_CODE_SESSION_ID' => CLAUDE_ID }, file)
    end
  end

  def prompt(turn = 'current', sidechain: false)
    { 'type' => 'user', 'sessionId' => CLAUDE_ID, 'promptId' => turn, 'isSidechain' => sidechain }
  end

  def response(model = 'claude-opus-5-5', effort = 'medium', sidechain: false)
    { 'type' => 'assistant', 'sessionId' => CLAUDE_ID, 'isSidechain' => sidechain, 'effort' => effort,
      'message' => { 'model' => model } }.compact
  end

  def claude_content
    { 'identity' => { 'agent' => 'Claude Code', 'provider' => 'Anthropic', 'model' => 'UNKNOWN',
                      'effort' => 'UNKNOWN' },
      'provenance' => { 'active_model' => 'UNKNOWN', 'active_effort' => 'UNKNOWN' } }
  end
end

class ClaudePublisherAttributionTest < Minitest::Test
  include ClaudePublisherAttributionFixture

  def test_served_model_and_effort_fill_unknown_fields_without_a_note
    with_claude_session(prompt('older'), response('claude-older', 'low'), prompt, response) do |environment, _file|
      result = prepare(environment)
      assert_equal({ 'agent' => 'Claude Code', 'provider' => 'Anthropic', 'model' => 'claude-opus-5-5',
                     'effort' => 'medium' }, result['identity'])
      assert_equal 'claude-opus-5-5', result.dig('provenance', 'active_model')
      assert_equal 'medium', result.dig('provenance', 'active_effort')
      assert_nil result['publisher_note']
    end
  end

  def test_conflicting_supplied_settings_are_refused
    with_claude_session(prompt, response) do |environment, _file|
      [%w[identity model], %w[identity effort], %w[provenance active_model]].each do |section, field|
        supplied = claude_content
        supplied[section][field] = 'wrong'
        error = assert_raises(Shaka::Error) { Shaka::PublisherAttribution.prepare(supplied, environment:) }
        assert_includes error.message, 'conflicts with native publisher settings'
      end
    end
  end

  def test_tool_results_continue_the_turn_they_answer
    with_claude_session(prompt, response, prompt) do |environment, _file|
      assert_equal 'claude-opus-5-5', prepare(environment).dig('identity', 'model')
    end
  end

  def test_new_turn_without_a_response_does_not_inherit_the_previous_turn
    with_claude_session(prompt('older'), response, prompt) do |environment, _file|
      result = prepare(environment)
      assert_equal 'UNKNOWN', result.dig('identity', 'model')
      assert_includes result['publisher_note'], 'UNKNOWN model, effort: Claude Code current turn'
    end
  end

  def test_prompts_without_an_identity_never_carry_earlier_settings_forward
    with_claude_session(prompt(nil), response, prompt(nil)) do |environment, _file|
      assert_equal 'UNKNOWN', prepare(environment).dig('identity', 'model')
    end
  end

  def test_subagent_and_host_notice_records_do_not_supply_settings
    records = [prompt, response, response('claude-haiku-5-5', 'low', sidechain: true),
               prompt('subagent', sidechain: true), response('<synthetic>', nil)]
    with_claude_session(*records) do |environment, _file|
      result = prepare(environment)
      assert_equal 'claude-opus-5-5', result.dig('identity', 'model')
      assert_equal 'medium', result.dig('identity', 'effort')
    end
  end

  def test_response_without_effort_keeps_the_model_and_explains_the_gap
    with_claude_session(prompt, response('claude-opus-5-5', nil)) do |environment, _file|
      result = prepare(environment)
      assert_equal 'claude-opus-5-5', result.dig('identity', 'model')
      assert_equal 'UNKNOWN', result.dig('provenance', 'active_effort')
      assert_equal 'UNKNOWN effort: Claude Code current turn settings unavailable.', result['publisher_note']
    end
  end

  def test_unreadable_tail_does_not_reuse_earlier_settings
    with_claude_session(prompt, response) do |environment, file|
      File.binwrite(file, "{\"model\":\"\xFF\"}\n{broken", mode: 'a')
      result = prepare(environment)
      assert_equal 'UNKNOWN', result.dig('identity', 'model')
      assert_includes result['publisher_note'], 'unreadable'
    end
  end

  def test_missing_or_ambiguous_session_is_unknown
    missing = { 'CLAUDE_CODE_SESSION_ID' => CLAUDE_ID, 'CLAUDE_CONFIG_DIR' => '/missing' }
    assert_includes prepare(missing)['publisher_note'], 'session unavailable or ambiguous'
    with_claude_session(prompt, response) do |environment, file|
      copy = File.join(environment.fetch('CLAUDE_CONFIG_DIR'), 'projects', 'other', File.basename(file))
      FileUtils.mkdir_p(File.dirname(copy))
      FileUtils.cp(file, copy)
      assert_equal 'UNKNOWN', prepare(environment).dig('identity', 'model')
    end
  end

  def test_two_detected_hosts_keep_the_unverified_note
    with_claude_session(prompt, response) do |environment, _file|
      result = prepare(environment.merge('CODEX_THREAD_ID' => CLAUDE_ID))
      assert_equal claude_content['identity'], result['identity']
      assert_includes result['publisher_note'], 'Native publisher settings unavailable'
    end
  end

  private

  def prepare(environment) = Shaka::PublisherAttribution.prepare(claude_content, environment:)
end
