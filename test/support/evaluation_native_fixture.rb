# frozen_string_literal: true

require 'json'

module EvaluationNativeFixture
  def setup_native_reader
    @helper = File.expand_path('../../skills/shaka/scripts/shaka', __dir__)
    @root = File.expand_path('../..', __dir__)
    @reader = Shaka::Evaluation::NativeUsage.new(helper: @helper, rate_root: @root)
  end

  def capture(host, rows)
    path = File.join(@directory, 'session.jsonl')
    File.write(path, rows.map { |row| JSON.generate(row) }.join("\n"))
    @reader.read(host: host, files: [path])
  end

  def assert_costs(result, neutral:, billed:)
    assert_in_delta neutral, result['cache_neutral_dollars'], 0.000001
    assert_in_delta billed, result['billed_dollars'], 0.000001
  end

  def codex_rows(input: 100_000, cached: 80_000)
    [
      { 'type' => 'session_meta', 'payload' => { 'model_provider' => 'openai', 'cli_version' => 'synthetic' } },
      { 'type' => 'turn_context', 'payload' => { 'turn_id' => 't', 'model' => 'gpt-6.1-sol', 'effort' => 'medium' } },
      { 'type' => 'token_usage_record', 'timestamp' => '2026-10-17T06:00:00Z',
        'payload' => { 'response_id' => 'r', 'turn_id' => 't', 'usage' => {
          'input_tokens' => input, 'cached_input_tokens' => cached, 'cache_write_input_tokens' => 0,
          'output_tokens' => 1000, 'reasoning_output_tokens' => 200
        } } }
    ]
  end

  def claude_rows
    [
      { 'type' => 'user', 'promptId' => 't' },
      { 'type' => 'assistant', 'promptId' => 't', 'version' => 'synthetic', 'effort' => 'medium',
        'timestamp' => '2026-10-17T06:00:00Z', 'message' => { 'id' => 'r', 'model' => 'claude-sonnet-5', 'usage' => {
          'input_tokens' => 10_000, 'cache_read_input_tokens' => 80_000, 'cache_creation_input_tokens' => 10_000,
          'cache_creation' => { 'ephemeral_5m_input_tokens' => 10_000, 'ephemeral_1h_input_tokens' => 0 },
          'output_tokens' => 1000, 'output_tokens_details' => { 'thinking_tokens' => 200 }, 'speed' => 'standard'
        } } }
    ]
  end
end
