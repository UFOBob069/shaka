# frozen_string_literal: true

require_relative 'local_review_comment_test'
require_relative 'github_helper'

class LocalReviewCommitPublishTest < Minitest::Test
  include LocalReviewCommentFixture

  # A small renderer sufficient for the layout checks, plus keyed upserts like GitHub.
  class Timeline < LocalReviewPublishTest::FakeGitHub
    def markdown(body)
      summaries = body.scan(%r{<summary>.*?</summary>}).join("\n")
      details = body.scan('<details>').join + summaries + body.scan('</details>').join
      tables = '<table></table>' * body.lines.count { |line| line.start_with?('| ---') }
      "#{details}#{tables}<p>#{body.lines.last.strip}</p>"
    end

    def api(path)
      super
      { 'message' => path.end_with?(LocalReviewCommentFixture::HEAD) ? 'Clarify review documentation' : 'Add review publication' }
    end

    def reply(body:, key:)
      existing = replies.find { |item| item.first == key }
      existing ? existing[1] = body : super
      { 'id' => replies.index { |item| item.first == key } + 1 }
    end
  end

  def test_two_reviewers_per_commit_leave_two_idempotent_timeline_comments
    github = publish_loop
    assert_equal [EARLIER, HEAD].map { |sha| "local-review-#{sha}" }, github.replies.map(&:first)
    github.replies.each_with_index { |(_, body), index| assert_commit_entry(body, index) }
  end

  def test_deepseek_report_publishes_through_the_same_exact_head_contract
    github = Timeline.new
    entry = clean(HEAD, 'deepseek/openrouter').merge('model' => 'deepseek/deepseek-v4.1-flash',
                                                     'coverage' => 'Supplied diff only; no filesystem access.')
    assert_equal 0, publish(github, 'rounds' => [entry]).first
    body = github.replies.first.last
    assert_includes body, 'deepseek/deepseek-v4.1-flash'
    assert_includes body, 'Supplied diff only'
    assert_equal "REVIEWED #{HEAD} BY deepseek/openrouter EFFORT UNKNOWN FINDINGS 0", body.lines.last.strip
  end

  def test_merge_accepts_the_final_commit_attestation_from_a_timeline_comment
    evidence = Struct.new(:issue_comments) { def viewer_login = 'agent' }
    result = Shaka::MergeReviewEvidence.new(evidence.new(timeline_comments), required: 'meaningful_changes').call(HEAD)

    assert_equal 'current_head', result['basis']
  end

  def test_a_fix_commit_opens_with_findings_from_the_previous_triage
    fixed = NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => HEAD)
    github = Timeline.new
    rounds = [round(EARLIER, findings: [fixed]), clean(HEAD, 'openai/codex')]
    assert_equal 0, publish(github, 'rounds' => rounds).first

    body = github.replies.last.last
    assert_operator body.index('Missing test'), :<, body.index('| Round |')
    assert_includes body, 'F1'
    refute_includes body, 'Clarify review documentation'
    refute_includes body, '**Triage of [`bbbbbbb`'
  end

  def test_an_invalid_later_report_prevents_all_timeline_writes
    github = Timeline.new
    rounds = [clean(EARLIER, 'openai/codex'), round(report: report(EARLIER))]

    assert_equal 1, publish(github, 'rounds' => rounds).first
    assert_empty github.replies
  end

  def test_commit_subject_cannot_add_disclosures_or_a_heading
    github = Timeline.new
    def github.api(path)
      super.merge('message' => '<details># Subject `code` [link](https://example.test) *all* ![x](image)</details>')
    end
    assert_equal 0, publish(github, 'rounds' => [clean(HEAD, 'openai/codex')]).first

    body = github.replies.first.last
    assert_includes body, '&#60;'
    assert_includes body, '&#91;'
    refute_includes body, '[link]'
    assert_equal 2, body.scan('<details>').size
  end

  def test_commit_subject_is_literal_text_including_quotes_mentions_and_urls
    github = Timeline.new
    def github.api(path)
      super.merge('message' => "Don't notify @someone https://example.test")
    end
    assert_equal 0, publish(github, 'rounds' => [clean(HEAD, 'openai/codex')]).first

    literal = "Don't notify @someone https://example.test"
    rendered_subject = github.replies.first.last[%r{<code>(.*?)</code>}, 1]
    assert_equal literal, CGI.unescapeHTML(rendered_subject)
  end

  private

  def publish_loop
    github = Timeline.new
    rounds = [clean(EARLIER, 'openai/codex'), clean(EARLIER, 'anthropic/claude'),
              clean(HEAD, 'openai/codex'), clean(HEAD, 'anthropic/claude')]
    2.times do
      status, output, = publish(github, 'rounds' => rounds)
      assert_equal 0, status
      assert_includes JSON.parse(output).fetch('summary'), '**Total:** 4 rounds'
    end
    github
  end

  def assert_commit_entry(body, index)
    head = [EARLIER, HEAD][index]
    assert_equal 3, body.scan('<details>').size
    assert_includes CGI.unescapeHTML(body), index.zero? ? 'Add review publication' : 'Clarify review documentation'
    refute_includes body, '**Total:**'
    assert_equal "REVIEWED #{head} BY anthropic/claude EFFORT UNKNOWN FINDINGS 0", body.lines.last.strip
  end

  def timeline_comments
    publish_loop.replies.map do |key, body|
      { 'user' => { 'login' => 'agent' }, 'body' => "<!-- shaka:reply:#{key} -->\n#{body}",
        'html_url' => 'https://example.test/review' }
    end
  end

  def publish(github, content)
    Tempfile.create(['content-', '.json']) do |file|
      file.write(JSON.generate(content))
      file.close
      out, err = capture_io do
        @status = Shaka::LocalReview.run(['publish', 'o/r', '7', '--content-file', file.path], github:)
      end
      [@status, out, err]
    end
  end

  def clean(head, reviewer)
    round(head, reviewer:, findings: [], report: report(head, reviewer:, findings: 0))
  end
end

# The API client validates reply keys before any request; the timeline fake does not.
class LocalReviewCommitPublicationKeyTest < Minitest::Test
  include LocalReviewCommentFixture
  include GitHubHelper

  def test_generated_commit_key_passes_real_reply_validation
    comment = Shaka::LocalReviewCommitComment.new({ 'rounds' => [round] }, head: HEAD, subject: ->(_) { 'Subject' })
    body = comment.render
    posted = "<!-- shaka:reply:#{comment.key} -->\n#{body}"
    github = client(response({ 'id' => 1, 'number' => 42, 'body' => '' }),
                    response({ 'login' => 'agent' }), response([]), html_response('<table></table>'),
                    response({ 'id' => 9, 'body' => posted }))

    assert_equal 9, github.reply(body:, key: comment.key)['id']
  end
end

# The API limit includes the reply marker, and a later oversized report must cause no writes.
class LocalReviewCommitSizeTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_reply_marker_counts_toward_the_limit_before_any_timeline_write
    github = LocalReviewCommitPublishTest::Timeline.new
    def github.api(_path) = { 'message' => 'Subject' }
    content = near_limit_content
    assert_operator comment(content).render.length, :<=, 65_536

    error = assert_raises(Shaka::Error) { Shaka::LocalReviewPublisher.new(content, github, 'o/r').publish }
    assert_includes error.message, HEAD[0, 7]
    assert_empty github.replies
  end

  private

  def near_limit_content
    last = round(report: report(body: ''))
    content = { 'rounds' => [round(EARLIER), last] }
    marker = "<!-- shaka:reply:local-review-#{HEAD} -->\n"
    padding = 65_536 - marker.length - comment(content).render.length + 1
    last['report'] = report(body: 'x' * padding)
    content
  end

  def comment(content)
    subject = ->(_) { '<code>&#83;&#117;&#98;&#106;&#101;&#99;&#116;</code>' }
    Shaka::LocalReviewCommitComment.new(content, head: HEAD, repository: 'o/r', published: ->(_) { true }, subject:)
  end
end

class LocalReviewReplyPreflightTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_a_later_reply_rendering_failure_prevents_all_writes
    github = LocalReviewCommitPublishTest::Timeline.new
    def github.markdown(body)
      html = super
      body.include?('Bad \n report') ? html.sub('<table>', '<p>Bad \n report</p><table>') : html
    end
    content = { 'rounds' => [round(EARLIER), round(report: report(body: 'Bad \n report'))] }
    error = assert_raises(Shaka::Error) { Shaka::LocalReviewPublisher.new(content, github, 'o/r').publish }
    assert_includes error.message, 'literal escape sequence'
    assert_empty github.replies
  end
end
