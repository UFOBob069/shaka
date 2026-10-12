# frozen_string_literal: true

require_relative 'post_implementation_disposition_test'

class EvaluationCheckpointMessageTest < Minitest::Test
  include PostImplementationDispositionFixture

  def test_ready_checkpoint_carries_copyable_message_and_coauthors_before_attestation
    with_result do |result, path|
      result['disposition'] = disposition('Merge')
      github, = publish(result, path)
      body = github.bodies.first.first
      assert_includes body, "```text\nFix checkpoint handoff (#1)\n```"
      assert_includes body,
                      "```text\nPut the merge text beside the recommendation.\n\n" \
                      "Co-authored-by: Ada <ada@example.test>\n```"
      assert_operator body.index('Squash commit message'), :<, body.index('<!-- shaka:post-implementation')
    end
  end

  def test_ready_publication_without_message_is_refused_before_any_write
    with_result do |result, path|
      File.write(path, JSON.generate(result))
      github = PostImplementationPublicationFixture::GitHub.new('a' * 40)
      status = nil
      capture_io do
        status = Shaka::PostImplementation.run(['publish', 'example/test', '1', '--content-file', path], github:)
      end
      assert_equal 1, status
      assert_empty github.bodies
    end
  end

  def test_blocked_owner_disposition_never_offers_merge_text
    with_result do |result, path|
      result['disposition'] = disposition('Revise before merge')
      github, status = publish(result, path)
      assert_equal 0, status
      refute_includes github.bodies.first.first, 'Squash commit message'
    end
  end
end
