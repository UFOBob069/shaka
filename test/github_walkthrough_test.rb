# frozen_string_literal: true

require_relative 'github_helper'

class GitHubWalkthroughTest < Minitest::Test
  include GitHubHelper

  def test_walkthrough_creates_comment_and_reads_back_the_review_and_head
    github = client(*publish_responses(snapshot_response), response([]))
    published = github.walkthrough(head: HEAD, body: WALKTHROUGH)
    assert_equal 'COMMENTED', published['state']
    assert_equal({ 'event' => 'COMMENT', 'commit_id' => HEAD, 'body' => WALKTHROUGH },
                 JSON.parse(@calls[7].last))
    assert_equal %w[gh api repos/owner/repo/pulls/42/reviews/123 --method GET --input -], @calls[8].first
  end

  def test_changed_or_closed_head_prevents_publication
    [snapshot_response(head: 'b' * 40), snapshot_response(state: 'CLOSED')].each do |snapshot|
      assert_raises(Shaka::Error) { client(snapshot).walkthrough(head: HEAD, body: WALKTHROUGH) }
      assert_equal 1, @calls.size
    end
  end

  def test_head_change_during_publication_is_reported
    github = client(*publish_responses(snapshot_response(head: 'b' * 40)))
    error = assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: WALKTHROUGH) }
    assert_includes error.message, '123'
    assert_equal 10, @calls.size
  end

  def test_review_readback_requires_matching_native_state_commit_body_and_id
    mismatches = [{ 'state' => 'APPROVED' }, { 'commit_id' => 'b' * 40 }, { 'body' => 'Wrong text.' }, { 'id' => 124 }]
    mismatches.each do |changes|
      github = client(snapshot_response, files_response, *gate_responses, html_response, review_response,
                      review_response(**changes))
      assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: WALKTHROUGH) }
      assert_equal 9, @calls.size
    end
  end

  def test_invalid_review_publication_result_is_a_domain_error
    github = client(snapshot_response, files_response, *gate_responses, html_response, response({}))
    assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: WALKTHROUGH) }
  end

  def test_invalid_body_or_head_never_contacts_github
    ['', '  ', "\xff".b, nil].each do |body|
      assert_raises(Shaka::Error) { client.walkthrough(head: HEAD, body: body) }
      assert_empty @calls
    end
    assert_raises(Shaka::Error) { client.walkthrough(head: 'short', body: WALKTHROUGH) }
    assert_empty @calls
  end

  def test_unauthorized_publication_does_not_attempt_readback
    github = client(snapshot_response, files_response, *gate_responses, html_response, response({}, status: 1))
    assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: WALKTHROUGH) }
    assert_equal 8, @calls.size
  end
end

class GitHubWalkthroughNotesTest < Minitest::Test
  include GitHubHelper

  NOTE = { 'path' => CHANGED_FILE, 'line' => 4, 'side' => 'RIGHT',
           'body' => "#{Shaka::Walkthrough::Notes::MARKER}\n🤖 Claude\n\nStart here." }.freeze

  def resolution_responses(classic: false, rules: [])
    rule = { 'refUpdateRule' => { 'requiresConversationResolution' => classic } }
    [response({ 'data' => { 'repository' => { 'pullRequest' => { 'baseRefName' => 'main', 'baseRef' => rule } } } }),
     response(rules)]
  end

  def note_publish_responses(stored, *extra)
    [snapshot_response, files_response, *gate_responses, html_response, html_response('<p>Start here.</p>'),
     *resolution_responses, review_response, review_response, response(stored), *extra]
  end

  def test_notes_are_posted_as_inline_comments_of_the_same_review
    stored = [{ 'path' => CHANGED_FILE, 'body' => NOTE['body'] }]
    github = client(*note_publish_responses(stored, snapshot_response, response([])))
    github.walkthrough(head: HEAD, body: WALKTHROUGH, notes: [NOTE])
    assert_equal [NOTE], JSON.parse(posted_review.last)['comments']
    assert(@calls.any? { |argv, _| argv.include?('repos/owner/repo/pulls/42/reviews/123/comments?per_page=100') })
  end

  def posted_review
    @calls.find { |argv, _| argv.include?('POST') && argv.include?('repos/owner/repo/pulls/42/reviews') }
  end

  def test_a_review_that_lost_a_note_is_reported
    github = client(*note_publish_responses([]))
    error = assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: WALKTHROUGH, notes: [NOTE]) }
    assert_includes error.message, 'did not keep its 1 notes'
  end

  def test_a_refused_review_names_each_note_location
    github = client(snapshot_response, files_response, *gate_responses, html_response, html_response,
                    *resolution_responses, response({}, status: 1, http_status: 422))
    error = assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: WALKTHROUGH, notes: [NOTE]) }
    assert_includes error.message, "check #{CHANGED_FILE}:L4."
  end

  def test_notes_are_refused_where_the_base_requires_conversation_resolution
    ruleset = [{ 'type' => 'pull_request', 'parameters' => { 'required_review_thread_resolution' => true } }]
    [resolution_responses(classic: true), resolution_responses(rules: ruleset)].each do |rules|
      github = client(snapshot_response, files_response, *gate_responses, html_response, html_response, *rules)
      error = assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: WALKTHROUGH, notes: [NOTE]) }
      assert_equal 'main requires conversation resolution before merging; publish the walkthrough without notes.',
                   error.message
      assert_nil posted_review
    end
  end
end
