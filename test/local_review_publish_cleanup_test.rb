# frozen_string_literal: true

require_relative 'local_review_commit_publish_test'

# Exercises publication and the real history cleanup together, including retryable failures.
class LocalReviewPublishCleanupSupport < Minitest::Test
  include LocalReviewCommentFixture

  class Timeline < LocalReviewCommitPublishTest::Timeline
    attr_accessor :head, :cleanup_failure
    attr_reader :edits

    def initialize
      super
      @head = LocalReviewCommentFixture::HEAD
      @comments = {}
      @edits = []
    end

    def repository = 'o/r'
    def viewer_login = 'agent'
    def issue_comments = @comments.values.map(&:dup)

    def reply(body:, key:)
      result = super
      id = result.fetch('id')
      @comments[id] = { 'id' => id, 'user' => { 'login' => viewer_login },
                        'created_at' => '2026-10-05T00:00:00Z',
                        'body' => "<!-- shaka:reply:#{key} -->\n#{body}" }
      result
    end

    # A comment the per-commit publisher left before this PR moved to one loop comment, holding `reports`.
    def add_per_commit_report(head, id, *reports)
      disclosures = reports.each_with_index.map do |report, index|
        summary = "Round #{index + 1} · #{head[0, 7]} · openai/codex"
        "<details>\n<summary>#{summary}</summary>\n\n#{report.strip}\n\n</details>"
      end
      body = "# Local Adversarial Review\n\n#{disclosures.join("\n\n")}\n\n" \
             "REVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\n"
      @comments[id] = { 'id' => id, 'user' => { 'login' => viewer_login }, 'created_at' => '2026-10-04T00:00:00Z',
                        'body' => "<!-- shaka:reply:local-review-#{head} -->\n#{body}" }
    end

    def add_continuation(key, head, id)
      body = "# Local Adversarial Review · earlier commits (1)\n\n" \
             "REVIEWED #{head} BY openai/codex EFFORT UNKNOWN FINDINGS 0\n"
      @comments[id] = { 'id' => id, 'user' => { 'login' => viewer_login }, 'created_at' => '2026-10-04T00:00:00Z',
                        'body' => "<!-- shaka:reply:#{key} -->\n#{body}" }
    end

    def add_legacy_report
      source = @comments.fetch(1)
      body = source['body'].sub(/local-review-loop-[a-f0-9]+/, 'local-adversarial-review')
      @comments[99] = source.merge('id' => 99, 'body' => body)
    end

    def api(path, method: 'GET', fields: {})
      return { 'head' => { 'sha' => head } } if path.end_with?('/pulls/7')
      return super(path) unless path.include?('/issues/comments/')

      comment = @comments.fetch(path.split('/').last.to_i)
      if method == 'PATCH'
        raise Shaka::Error, 'Cleanup denied' if cleanup_failure

        @edits << comment.fetch('id')
        comment['body'] = fields.fetch(:body)
      end
      comment.dup
    end

    def verify_rendering(body)
      return super unless body.include?(Shaka::LocalReviewHistory::MARKER) || body.start_with?("\nREVIEWED ")

      attestation = body.lines.reverse.find { |line| line.start_with?('REVIEWED ') }.strip
      footer = "<p>#{attestation}</p>"
      body.include?(Shaka::LocalReviewHistory::MARKER) ? "<details><p>History</p></details>#{footer}" : footer
    end
  end

  private

  def legacy_body(github) = github.issue_comments.find { |comment| comment['id'] == 99 }.fetch('body')

  def current_visible(github) = github.issue_comments.last.fetch('body').split('<details>').first

  def earlier_defect = round(EARLIER, findings: [NIT.merge('class' => 'defect')])

  def publish_previous_ledger(github)
    github.head = EARLIER
    previous = { 'rounds' => [round(EARLIER, findings: [NIT.merge('class' => 'defect')])] }
    assert_equal 0, publish(github, previous).first
    github.head = HEAD
    github.issue_comments.first.fetch('body')
  end

  def per_commit_timeline(content = loop_content)
    github = Timeline.new
    content['rounds'].zip([50, 51]) do |round, id|
      github.add_per_commit_report(round['head'], id, File.read(round['report']))
    end
    github
  end

  def comment(github, id) = github.issue_comments.find { |item| item['id'] == id }.fetch('body')

  # The earlier commit's per-commit comment points at the loop comment; like any report of the
  # current commit, the current one stays visible.
  def assert_preserved_history(github)
    body = comment(github, 50)
    assert_includes body, Shaka::LocalReviewHistory::MARKER
    assert_includes body, '#issuecomment-1'
    assert_equal "REVIEWED #{EARLIER} BY openai/codex EFFORT UNKNOWN FINDINGS 0", body.lines.last.strip
    [1, 51].each { |id| refute_includes comment(github, id), Shaka::LocalReviewHistory::MARKER }
  end

  def assert_failed_cleanup(github, result)
    assert_equal 1, result.fetch('comments').size
    assert_includes result.fetch('cleanup').fetch('unavailable').join, 'Cleanup denied'
    assert_equal 3, github.issue_comments.size
    refute_includes comment(github, 50), Shaka::LocalReviewHistory::MARKER
  end

  def loop_content
    rounds = [EARLIER, HEAD].map { |head| round(head, findings: [], report: report(head, findings: 0)) }
    { 'rounds' => rounds }
  end

  def publish(github, content)
    Tempfile.create(['content-', '.json']) do |file|
      file.write(JSON.generate(content))
      file.close
      output, = capture_io do
        @status = Shaka::LocalReview.run(['publish', 'o/r', '7', '--content-file', file.path], github:)
      end
      [@status, JSON.parse(output)]
    end
  end
end

class LocalReviewPublishCleanupTest < LocalReviewPublishCleanupSupport
  def test_publication_collapses_the_per_commit_reports_it_replaces
    github = per_commit_timeline
    content = loop_content

    status, result = publish(github, content)
    assert_equal 0, status
    assert_equal [50], result.fetch('cleanup').fetch('collapsed')
    assert_empty result.fetch('cleanup').fetch('unavailable')
    assert_preserved_history(github)
  end

  def test_republishing_keeps_one_archive_disclosure_and_one_loop_comment
    github = per_commit_timeline
    content = loop_content
    assert_equal 0, publish(github, content).first
    assert_equal 0, publish(github, content).first
    assert_equal 1, comment(github, 50).scan('<summary>Earlier local review</summary>').size
    assert_equal 3, github.issue_comments.size
  end

  def test_cleanup_failure_retains_publication_and_reports_a_retryable_gap
    github = per_commit_timeline
    github.cleanup_failure = true
    content = loop_content

    status, result = publish(github, content)
    assert_equal 1, status
    assert_failed_cleanup(github, result)
    github.cleanup_failure = false
    assert_equal 0, publish(github, content).first
    assert_equal 3, github.issue_comments.size
    assert_includes comment(github, 50), Shaka::LocalReviewHistory::MARKER
  end

  def test_another_ledgers_per_commit_report_of_an_earlier_commit_stays_visible
    github = Timeline.new
    github.add_per_commit_report(EARLIER, 52, File.read(report(EARLIER, body: "1. [P1] Unrelated defect.\n")))

    assert_equal 0, publish(github, loop_content).first

    refute_includes comment(github, 52), Shaka::LocalReviewHistory::MARKER
  end

  def test_a_per_commit_comment_also_holding_another_ledgers_report_stays_visible
    content = loop_content
    github = Timeline.new
    other = File.read(report(EARLIER, body: "1. [P1] Unrelated defect.\n"))
    github.add_per_commit_report(EARLIER, 53, File.read(content['rounds'][0]['report']), other)

    assert_equal 0, publish(github, content).first

    refute_includes comment(github, 53), Shaka::LocalReviewHistory::MARKER
  end

  def test_a_failed_listing_of_replaced_comments_is_a_retryable_gap
    github = per_commit_timeline
    def github.issue_comments = raise(Shaka::Error, 'Listing denied')

    status, result = publish(github, loop_content)
    assert_equal 1, status
    assert_includes result.fetch('cleanup').fetch('unavailable').join, 'Listing denied'
    assert_equal 1, result.fetch('comments').size
  end

  def test_a_continuation_a_repacking_no_longer_writes_is_retired
    github = Timeline.new
    content = loop_content
    key = Shaka::LocalReviewLoopComment.new(content).key
    github.add_continuation("#{key}-1", EARLIER, 60)

    assert_equal 0, publish(github, content).first

    assert_includes comment(github, 60), Shaka::LocalReviewHistory::MARKER
  end

  def test_no_current_head_report_preserves_history_and_reports_the_skip
    github = Timeline.new
    github.head = 'c' * 40

    status, result = publish(github, loop_content)
    assert_equal 0, status
    assert_includes result.fetch('cleanup').fetch('skipped'), 'No current report'
    assert_empty github.edits
  end
end

class LocalReviewPublishPreservationTest < LocalReviewPublishCleanupSupport
  def test_a_fresh_ledger_preserves_reports_it_does_not_account_for
    github = Timeline.new
    original = publish_previous_ledger(github)
    current = { 'rounds' => [round(HEAD, findings: [], report: report(HEAD, findings: 0))] }

    status, result = publish(github, current)

    assert_equal 0, status
    assert_empty result.fetch('cleanup').fetch('collapsed')
    assert_equal original, github.issue_comments.first.fetch('body')
  end

  def test_an_earlier_unresolved_finding_stays_visible_after_a_clean_review
    github = Timeline.new
    content = loop_content
    content['rounds'][0] = earlier_defect

    assert_equal 0, publish(github, content).first

    visible = current_visible(github)
    assert_includes visible, NIT.fetch('summary')
    assert_includes visible, '| Unassessed | openai/codex |'
    assert_empty github.edits
  end

  def test_a_separate_legacy_report_at_a_ledger_head_stays_visible
    github = Timeline.new
    publish_previous_ledger(github)
    github.add_legacy_report
    original = legacy_body(github)

    assert_equal 0, publish(github, loop_content).first

    assert_equal original, legacy_body(github)
    assert_empty github.edits
  end

  def test_republishing_an_old_ledger_skips_cleanup_behind_an_unrelated_current_report
    github = Timeline.new
    assert_equal 0, publish(github, loop_content).first
    github.edits.clear
    old = { 'rounds' => [earlier_defect] }

    status, result = publish(github, old)

    assert_equal 0, status
    assert_includes result.fetch('cleanup').fetch('skipped'), 'No current report'
    assert_empty github.edits
  end
end
