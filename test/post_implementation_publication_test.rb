# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/post_implementation'

module PostImplementationPublicationFixture
  class GitHub < Shaka::GitHub
    attr_reader :bodies, :description_body
    attr_writer :walkthrough

    def initialize(head)
      super('example/test', '1')
      @head = head
      @walkthrough = head
      @bodies = []
      @draft = false
      @description_body = "<!-- shaka:begin -->\nFeature summary\n<!-- shaka:end -->\n\nHuman notes"
    end

    def snapshot
      { 'state' => 'OPEN', 'headRefOid' => @head, 'isDraft' => @draft, 'id' => 'PR_1',
        'commits' => { 'totalCount' => 1 } }
    end

    def api(path, method: 'GET', fields: {})
      return { 'login' => viewer_login } if path == 'user'

      @description_body = fields.fetch(:body) if method == 'PATCH'
      { 'state' => 'open', 'draft' => @draft, 'head' => { 'sha' => @head }, 'base' => { 'sha' => 'b' * 40 },
        'body' => @description_body }
    end

    def graphql(_query, **)
      @draft = true
      { 'convertPullRequestToDraft' => { 'pullRequest' => snapshot.slice('id', 'isDraft', 'headRefOid') } }
    end

    def verify_rendering(body, **) = body

    def api_list(path)
      return walkthroughs if path.include?('/reviews')

      [{ 'commit' => { 'message' => "Fix\n\nCo-authored-by: Ada <ada@example.test>" } }]
    end

    def walkthroughs
      return [] unless @walkthrough

      footer = "_Walkthrough for commit `#{@walkthrough}`. This is a COMMENT, not an approval._"
      [{ 'user' => { 'login' => viewer_login }, 'state' => 'COMMENTED', 'commit_id' => @walkthrough,
         'body' => "🤖 Codex · OpenAI · UNKNOWN · UNKNOWN\n\n# Code Walkthrough\n\nSteps.\n\n#{footer}" }]
    end

    def viewer_login = 'test-author'

    def issue_comments = [@published]

    def reply(body:, key:)
      @bodies << [body, key]
      @published = { 'id' => 1, 'created_at' => '2026-09-30T00:00:00Z', 'user' => { 'login' => viewer_login },
                     'body' => "<!-- shaka:reply:#{key} -->\n#{body}",
                     'html_url' => 'https://github.com/example/test/pull/1#issuecomment-1' }
    end
  end

  private

  def bounded_read
    read = File.method(:binread)
    File.define_singleton_method(:binread) do |file, length|
      raise 'Unbounded report read' unless length == 100_001

      read.call(file, length)
    end
    yield
  ensure
    File.define_singleton_method(:binread, read)
  end

  def attach_private_usage(result, path)
    usage = File.join(File.dirname(path), 'usage.json')
    File.write(usage, JSON.generate(type: 'result', result: 'PRIVATE TRANSCRIPT', session_id: 'test',
                                    model: 'observed-model', usage: { input_tokens: 17, output_tokens: 2 }))
    result['usage'] = usage
    result['reviewer'] = 'anthropic/claude'
  end

  def with_result
    Dir.mktmpdir do |root|
      report = File.join(root, 'report.json')
      File.write(report, JSON.generate(head: 'a' * 40, conclusion: 'Proceed', reasons: ['Useful change'],
                                       concerns: [], alternative: 'No change leaves the bug',
                                       verification_adequacy: ADEQUACY))
      result = { 'purpose' => 'post_implementation', 'status' => 'completed', 'head' => 'a' * 40,
                 'report' => report, 'reviewer' => 'openai/codex', 'effort' => 'medium',
                 'prompt_source' => 'Shaka default', 'execution_id' => 'abc12345' }
      yield result, File.join(root, 'result.json')
    end
  end

  def message_file(path)
    message = File.join(File.dirname(path), 'message.json')
    File.write(message,
               JSON.generate(title: 'Fix checkpoint handoff', body: 'Put the merge text beside the recommendation.'))
    message
  end

  def publish(result, path, github: GitHub.new('a' * 40))
    message = message_file(path)
    File.write(path, JSON.generate(result))
    status = nil
    output = capture_io do
      status = Shaka::PostImplementation.run(
        ['publish', 'example/test', '1', '--content-file', path, '--squash-message', message], github:
      )
    end.first
    [github, status, output]
  end
end

class PostImplementationPublicationTest < Minitest::Test
  include PostImplementationPublicationFixture

  def test_publication_keeps_execution_metadata_without_private_native_content
    with_result do |result, path|
      attach_private_usage(result, path)
      github, status = publish(result, path)

      assert_equal 0, status
      identity = "🤖 Claude · Anthropic · observed-model · UNKNOWN\n\n# Checkpoint for "
      assert github.bodies.first.first.start_with?(identity)
      refute_includes github.bodies.first.first, 'PRIVATE TRANSCRIPT'
    end
  end

  def test_usage_is_one_token_line_and_a_pinned_prompt_links_to_its_file
    with_result do |result, path|
      attach_private_usage(result, path)
      file = '.agents/shaka/product-checkpoint.md'
      result['prompt_source'] = "#{'c' * 40}:#{file}"
      body = publish(result, path).first.bodies.first.first
      tokens = '1 response: 17 input, UNKNOWN cached input, UNKNOWN cache writes, 2 output'
      assert_match(/Native usage \(.*observed-model.*\), #{tokens}/, body)
      refute_includes body, '```json'
      assert_includes body, "prompt: [`#{file}`](https://github.com/example/test/blob/#{'c' * 40}/#{file})"
    end
  end

  def test_token_totals_group_thousands_and_an_unpinned_prompt_stays_plain
    publication = Shaka::PostImplementationPublication.new({ 'prompt_source' => 'Shaka default' },
                                                           head: 'a' * 40, repository: 'example/test')

    assert_equal '1,234,567',
                 publication.send(:token_total, [{ 'usage' => { 'total_tokens' => 1_234_567 } }], 'total_tokens')
    assert_equal 'Shaka default', publication.send(:prompt_text)
  end

  def test_alternative_label_fits_a_report_that_proposes_no_change
    with_result do |result, path|
      github, = publish(result, path)

      assert_includes github.bodies.first.first, 'Alternative considered: No change leaves the bug'
      refute_includes github.bodies.first.first, 'Simpler alternative:'
    end
  end

  def test_stale_head_and_technical_evidence_cannot_be_published_as_checkpoint
    with_result do |result, path|
      result['head'] = 'b' * 40
      github, status = publish(result, path)

      assert_equal 1, status
      assert_empty github.bodies
      result['head'] = 'a' * 40
      result['purpose'] = 'technical_review'
      assert_equal 1, publish(result, path)[1]
    end
  end

  def test_another_execution_does_not_overwrite_the_earlier_conclusion
    with_result do |result, path|
      first, = publish(result, path)
      result['execution_id'] = 'def56789'
      second, = publish(result, path)

      refute_equal first.bodies.first.last, second.bodies.first.last
    end
  end

  def test_nonobject_and_incomplete_results_fail_without_a_backtrace
    with_result do |valid, path|
      [nil, true, 42, [1], valid.except('report'), valid.merge('report' => nil)].each do |result|
        github, status = publish(result, path)

        assert_equal 1, status
        assert_empty github.bodies
      end
    end
  end

  def test_oversized_report_read_is_bounded_and_cannot_publish
    with_result do |result, path|
      File.write(result.fetch('report'), 'x' * 1_000_000)
      github, status = publish(result, path)
      assert_equal 1, status
      assert_empty github.bodies
      error = bounded_read do
        assert_raises(Shaka::Error) { Shaka::PostImplementationReport.read(result.fetch('report'), head: 'a' * 40) }
      end
      assert_includes error.message, 'exceeds 100 KB'
    end
  end
end

class PostImplementationPublicationHistoryTest < Minitest::Test
  include PostImplementationPublicationFixture

  def test_publication_confirms_history_updates
    with_result do |result, path|
      outcome = publish(result, path)
      assert_includes outcome[0].bodies.first.first, 'observed model: UNKNOWN'
      assert_equal({ 'collapsed' => [], 'unavailable' => [] }, JSON.parse(outcome[2]).fetch('earlier_checkpoints'))
    end
  end

  def test_history_failure_is_explicit_after_the_new_report_is_published
    with_result do |result, path|
      github = GitHub.new('a' * 40)
      github.define_singleton_method(:issue_comments) { raise Shaka::Error, 'Listing unavailable' }
      outcome = publish(result, path, github:)
      assert_equal 1, outcome[1]
      assert_equal 1, github.bodies.size
      assert_equal ['Listing unavailable'], JSON.parse(outcome[2]).dig('earlier_checkpoints', 'unavailable')
    end
  end
end

class PostImplementationFailureReasonTest < Minitest::Test
  include PostImplementationPublicationFixture

  def test_invalid_failure_reasons_are_refused_before_publication
    [nil, 42, ''].each do |reason|
      with_result do |result, path|
        outcome = publish(result.merge('status' => 'not_completed', 'reason' => reason), path)
        assert_equal 1, outcome[1]
        assert_empty outcome[0].bodies
        refute outcome[0].snapshot['isDraft']
      end
    end
  end
end
