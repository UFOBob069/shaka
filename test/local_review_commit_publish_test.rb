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

  def test_two_reviewers_per_commit_leave_one_idempotent_comment
    github = publish_loop
    assert_equal 1, github.replies.size
    assert_match(/\Alocal-review-loop-#{EARLIER[0, 12]}-\h{12}\z/, github.replies.first.first)
    assert_loop_comment(github.replies.first.last)
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
    assert_equal 3, body.scan('<details>').size
  end

  def test_commit_subject_is_literal_text_including_quotes_mentions_and_urls
    github = Timeline.new
    def github.api(path)
      super.merge('message' => "Don't notify @someone https://example.test")
    end
    assert_equal 0, publish(github, 'rounds' => [clean(HEAD, 'openai/codex')]).first

    rendered_subject = github.replies.first.last[%r{<code>(.*?)</code>}, 1]
    assert_equal "Don't notify @someone https://example.test", CGI.unescapeHTML(rendered_subject)
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

  # One findings disclosure, then each commit's disclosure holding its two reports. The outcome and
  # coverage appear once however many commits were reviewed.
  def assert_loop_comment(body)
    once = ["# Local Adversarial Review\n", '**Outcome:**', '**Coverage:**', 'Usage and attribution']
    assert_equal([1] * once.size, once.map { |text| body.scan(text).size })
    assert_includes body, '| openai/codex: 0 · anthropic/claude: 0 |'
    assert_equal 7, body.scan('<details>').size
    assert_includes CGI.unescapeHTML(body), "[`bbbbbbb`](https://github.com/o/r/commit/#{EARLIER}) <code>Add review"
    assert_equal "REVIEWED #{HEAD} BY anthropic/claude EFFORT UNKNOWN FINDINGS 0", body.lines.last.strip
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
    comment = Shaka::LocalReviewLoopComment.new({ 'rounds' => [round] }, subject: ->(_) { 'Subject' })
    body = comment.render
    posted = "<!-- shaka:reply:#{comment.key} -->\n#{body}"
    github = client(response({ 'id' => 1, 'number' => 42, 'body' => '' }),
                    response({ 'login' => 'agent' }), response([]), html_response('<table></table><table></table>'),
                    response({ 'id' => 9, 'body' => posted }))

    assert_equal 9, github.reply(body:, key: comment.key)['id']
  end
end

# The API limit includes the reply marker. Reports past it move to an earlier-commits comment;
# a single commit that cannot fit causes no writes.
class LocalReviewCommitSizeTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_reply_marker_counts_toward_the_limit_and_moves_the_oldest_reports
    github = LocalReviewCommitPublishTest::Timeline.new
    content = near_limit_content
    assert_operator comment(content).parts.first.body.length, :<=, 65_536

    Shaka::LocalReviewPublisher.new(content, github, 'o/r').publish

    (main_key, main), (earlier_key, earlier) = github.replies
    assert_equal "#{main_key}-1", earlier_key
    assert_includes main, 'reports in earlier comment 1'
    assert_closes(main, HEAD, without: EARLIER)
    assert_closes(earlier, EARLIER, without: HEAD)
  end

  def test_separate_ledgers_from_the_same_commit_keep_separate_comments
    first = { 'rounds' => [round(EARLIER)] }
    second = { 'rounds' => [round(EARLIER, report: report(EARLIER, body: "2. [P1] Other finding.\n"))] }

    refute_equal comment(first).key, comment(second).key
    assert_equal comment(first).key, comment(JSON.parse(JSON.generate(first))).key
  end

  def test_ledgers_with_identical_first_reports_keep_separate_comments_by_ledger_id
    first = { 'id' => 'a' * 12, 'rounds' => [round(EARLIER)] }
    second = { 'id' => 'b' * 12, 'rounds' => [round(EARLIER)] }

    refute_equal comment(first).key, comment(second).key
    assert_equal "local-review-loop-#{EARLIER[0, 12]}-#{'a' * 12}", comment(first).key
  end

  def test_one_commit_too_large_for_any_comment_prevents_all_writes
    github = LocalReviewCommitPublishTest::Timeline.new
    content = { 'rounds' => [round(EARLIER), round(report: report(body: 'x' * 65_536))] }

    error = assert_raises(Shaka::Error) { Shaka::LocalReviewPublisher.new(content, github, 'o/r').publish }
    assert_includes error.message, '65536'
    assert_empty github.replies
  end

  private

  def assert_closes(body, head, without:)
    assert_includes body, "<summary>Commit #{head[0, 7]}"
    refute_includes body, "<summary>Commit #{without[0, 7]}"
    assert_equal "REVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 1", body.lines.last.strip
  end

  # Exactly one character over the limit with both commits' reports in the main comment.
  def near_limit_content
    last = round(report: report(body: ''))
    content = { 'rounds' => [round(EARLIER), last] }
    marker = "<!-- shaka:reply:#{comment(content).key} -->\n"
    padding = 65_536 - marker.length - comment(content).render.length + 1
    last['report'] = report(body: 'x' * padding)
    content
  end

  def comment(content)
    subject = ->(_) { '<code>&#83;&#117;&#98;&#106;&#101;&#99;&#116;</code>' }
    Shaka::LocalReviewLoopComment.new(content, repository: 'o/r', published: ->(_) { true }, subject:)
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

  # https://github.com/shakacode/shaka/issues/478: the rendering check counted the literal
  # excerpt's separator line as a table GitHub failed to render.
  def test_a_report_with_a_coverage_table_is_published
    github = LocalReviewCommitPublishTest::Timeline.new
    # GitHub shows a pre block as literal text, so a table inside one never renders.
    def github.markdown(body) = super(body.gsub(%r{^<pre>.*?</pre>}m, ''))
    table = "| Id | Status |\n| --- | --- |\n| F1 | Resolved |"
    report = report(body: "## Coverage\n\n#{table}\n\n## Findings\n\nNone.\n", findings: 0)
    Shaka::LocalReviewPublisher.new({ 'rounds' => [round(findings: [], report:)] }, github, 'o/r').publish

    assert_includes github.replies.first.last, "<pre>#{table.gsub('|', '&#124;')}</pre>"
  end
end
