# frozen_string_literal: true

require_relative 'local_review_test'
require_relative 'local_review_commit_publish_test'

module LocalReviewUsageBridgeFixture
  include LocalReviewFixture

  THREAD = '00000000-0000-0000-0000-000000000579'

  private

  def with_captured_review(reviewer: 'anthropic/claude', **options)
    with_repository do |root, base, head, bin|
      Dir.mktmpdir do |directory|
        fake_usage_cli(bin, head, reviewer, options)
        ledger = File.join(directory, 'ledger.json')
        output, error, status = run_review(root, base, head, bin, ledger:, reviewer:,
                                                                  env: { 'CODEX_HOME' => directory })
        result = assert_successful_review(output, error, status, head, reviewer)
        yield ledger, result
      end
    end
  end

  def fake_usage_cli(bin, head, reviewer, options)
    if reviewer == 'openai/codex'
      fake_usage_codex(bin, head, **options)
    else
      native = claude_native(head)
      native.merge!(options.fetch(:native, {}))
      write_executable(bin, 'claude', "#!/usr/bin/env ruby\nputs #{JSON.generate(native).inspect}\n")
    end
  end

  def triage_and_remove_source(ledger, result, content = { 'findings' => [] })
    FileUtils.rm_f(result['usage']) if result['usage']
    Shaka::LocalReviewLedger.new(ledger).record!(content)
    JSON.parse(File.read(ledger))
  end

  def claude_native(head)
    { type: 'result', session_id: THREAD, is_error: false,
      result: "No findings\nREVIEWED #{head} BY anthropic/claude EFFORT medium FINDINGS 0",
      model: 'claude-opus-5-5', total_cost_usd: 0.42, usage: claude_counters,
      private_text: 'PRIVATE TRANSCRIPT' }
  end

  def claude_counters
    { input_tokens: 6, cache_read_input_tokens: 78_309,
      cache_creation_input_tokens: 26_042, output_tokens: 4521 }
  end

  def fake_usage_codex(bin, head, missing: false)
    write_executable(bin, 'codex', <<~SCRIPT)
      #!/usr/bin/env ruby
      require 'json'
      require 'fileutils'
      File.write(ARGV.fetch(ARGV.index('-o') + 1), "No findings\\nREVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\\n")
      unless #{missing}
        folder = FileUtils.mkdir_p(File.join(ENV.fetch('CODEX_HOME'), 'sessions', '2026', '10', '16')).first
        File.write(File.join(folder, 'rollout-#{THREAD}.jsonl'), #{codex_records.map { |record| JSON.generate(record) }.join("\n").inspect})
      end
      puts JSON.generate(type: 'thread.started', thread_id: '#{THREAD}')
    SCRIPT
  end

  def codex_records
    [{ type: 'session_meta', payload: { id: THREAD, model_provider: 'openai' } },
     { type: 'turn_context', payload: { turn_id: 'review', model: 'gpt-6.1-sol', effort: 'medium' } },
     { type: 'token_usage_record', payload: { response_id: 'response', turn_id: 'review', usage: codex_counters } }]
  end

  def codex_counters
    { input_tokens: 158_831, cached_input_tokens: 134_528, output_tokens: 1265, cache_write_input_tokens: 0 }
  end

  def publish_twice(content)
    github = LocalReviewCommitPublishTest::Timeline.new
    2.times { Shaka::LocalReviewPublisher.new(content, github, 'o/r').publish }
    assert_equal 1, github.replies.size
    github.replies.first.last
  end

  def attached_description(result, content: { 'usage' => { 'note' => '', 'records' => [] } })
    Tempfile.create(['result-', '.json']) do |file|
      file.write(JSON.generate(result))
      file.close
      Shaka::LocalReviewUsage.attach(content, [file.path, file.path])
    end
  end

  def shared_partial_native
    { total_cost_usd: nil, modelUsage: { 'a' => { 'canonicalModel' => 'claude-opus-5-5' },
                                         'b' => { 'canonicalModel' => 'claude-sonnet-4-5' } },
      usage: claude_counters.except(:cache_read_input_tokens) }
  end
end
