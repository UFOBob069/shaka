# frozen_string_literal: true

require_relative 'local_review_commit_publish_test'
require_relative 'github_publication_test'

class LocalReviewPresentationTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_earlier_concerns_survive_a_clean_head_and_reclassification
    defect = NIT.merge('id' => 'D1', 'class' => 'defect', 'summary' => 'Lost writes')
    risk = NIT.merge('id' => 'R1', 'class' => 'risk', 'summary' => 'Unassessed retry risk')
    rounds = [round(EARLIER, findings: [defect, risk], report: report(EARLIER, findings: 2)),
              round(findings: [defect.merge('class' => 'nit')])]
    visible = comment(rounds).render.split('<details>').first
    assert_includes visible, 'Lost writes'
    assert_includes visible, 'Unassessed retry risk'
    refute_includes visible, 'nothing left to fix'
  end

  def test_settled_dispositions_are_collapsed_once_and_reports_are_preserved
    fixed = NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => HEAD)
    rounds = [round(EARLIER, findings: [fixed]), round(findings: [NIT.merge('id' => 'N2')])]
    body = comment(rounds).render
    assert_settled_layout(body)
    assert_includes body, File.read(rounds.last['report']).strip
  end

  def assert_settled_layout(body)
    visible, = body.split('<details>', 2)
    refute_includes visible, '| Round |'
    refute_includes visible, 'Missing test'
    assert_equal 1, body.scan('— documented nit').size
    assert_equal 1, body.scan('— fixed in').size
    assert_equal "REVIEWED #{HEAD} BY openai/codex EFFORT UNKNOWN FINDINGS 1", body.lines.last.strip
  end

  def test_coverage_limitations_and_unknown_coverage_stay_visible
    explicit = round(coverage: 'Diff only; unchanged callers and tests were not inspected.')
    visible = comment([explicit]).render.split('<details>').first
    assert_includes visible, explicit['coverage']
    assert_match(/coverage.*UNKNOWN/im, comment([round]).render.split('<details>').first)
  end

  def test_returned_finding_is_visible_even_when_reclassified_as_a_nit
    fixed = NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => HEAD)
    body = comment([round(EARLIER, findings: [fixed]), round]).render
    assert_includes body.split('<details>').first, 'returned after its fix'
  end

  def test_an_earlier_comment_never_borrows_a_later_clean_outcome
    defect = NIT.merge('class' => 'defect')
    rounds = [round(EARLIER, findings: [defect]), clean_round]
    body = comment(rounds, head: EARLIER).render
    assert_includes body.split('<details>').first, 'Missing test'
    assert_equal "REVIEWED #{EARLIER} BY openai/codex EFFORT UNKNOWN FINDINGS 1", body.lines.last.strip
  end

  def test_a_clean_later_round_does_not_hide_an_earlier_defect
    defect = NIT.merge('class' => 'defect')
    body = comment([round(EARLIER, findings: [defect]), clean_round]).render
    assert_includes body.split('<details>').first, 'Missing test'
  end

  def test_same_head_reporters_do_not_make_a_fixed_finding_look_returned
    fixed = NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => HEAD)
    other = round(EARLIER, reviewer: 'anthropic/claude', findings: [fixed],
                           report: report(EARLIER, reviewer: 'anthropic/claude'))
    body = comment([round(EARLIER, findings: [fixed]), other, clean_round]).render
    refute_includes body, 'returned after its fix'
    assert_equal 1, body.scan('— fixed in').size
  end

  def test_report_specific_limits_remain_in_evidence_in_both_report_formats
    ["## Coverage\n\nCould not inspect the unchanged retry caller.\n\n## Findings\n",
     "**Coverage:** Could not inspect the unchanged retry caller.\n\n"].each do |intro|
      entry = round(report: report(body: "#{intro}1. Missing test"))
      visible = comment([entry]).render.split('<details>', 2).last.split('### Execution metadata').first
      assert_includes visible, 'Could not inspect the unchanged retry caller.'
      refute_includes visible, '1. Missing test'
    end
  end

  def test_published_report_links_to_consolidated_pr_usage
    github = LocalReviewCommitPublishTest::Timeline.new
    Shaka::LocalReviewPublisher.new({ 'rounds' => [round] }, github, 'o/r').publish
    assert_includes github.replies.first.last, '[Usage and attribution](https://github.com/o/r/pull/7)'
  end

  def test_coverage_preserves_fenced_examples_and_their_heading_lines
    ["```sh\n# unit tests\nbundle exec rake test\n```",
     "~~~~text\n## Findings inside an example\n\nNot a boundary.\n~~~~~"].each do |example|
      intro = "## Coverage\nRan:\n#{example}\n\nMissing the integration environment.\n\n## Findings\n"
      body = comment([round(report: report(body: "#{intro}1. Missing test"))]).render
      visible = body.split('<details>', 2).last.split('### Execution metadata').first
      assert_includes visible, example
      assert_includes visible, 'Missing the integration environment.'
      refute_includes visible, '1. Missing test'
    end
  end

  def test_legacy_coverage_keeps_blank_lines_inside_fences
    example = "```text\nfirst command\n\n# second command\n```"
    entry = round(report: report(body: "**Coverage:** Ran:\n#{example}\n\n1. Missing test"))
    assert_includes comment([entry]).render.split('<details>', 2).last, example
  end

  private

  def clean_round = round(findings: [], report: report(findings: 0))

  def comment(rounds, head: HEAD)
    Shaka::LocalReviewCommitComment.new({ 'rounds' => rounds }, head:, subject: ->(_) { 'Subject' })
  end
end

class UnchangedReviewReplyTest < Minitest::Test
  include PublicationFixtures

  def test_identical_owned_reply_is_validated_without_a_write
    posted = "<!-- shaka:reply:review -->\n#{BODY}"
    existing = keyed(7, posted)
    github = client(pull_response(''), viewer_response, response([existing]), html_response('<p>ok</p>'))
    assert_equal existing, github.reply(body: BODY, key: 'review')
    refute(@calls.any? { |argv, _| argv.include?('PATCH') })
  end
end

class ReviewCollationPresentationTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_visible_finding_names_every_reporter_once_across_review_rounds
    risk = NIT.merge('class' => 'risk')
    other = round(reviewer: 'anthropic/claude', findings: [risk],
                  report: report(reviewer: 'anthropic/claude'))
    body = comment([round(EARLIER, findings: [risk]), round(findings: [risk]), other]).render
    finding = body.split('<details>').first.lines.find { |line| line.start_with?('| `F1`') }

    assert_includes finding, '| openai/codex, anthropic/claude |'
    assert_equal 1, finding.scan('openai/codex').size
  end

  def test_solo_reviews_do_not_show_collation_even_across_commits
    rounds = [round(EARLIER), round]
    refute_includes comment(rounds).render, '**Collated as:**'
    refute_includes Shaka::LocalReviewComment.new({ 'rounds' => rounds }).render, '**Collated as:**'
  end

  def test_same_commit_reviewers_keep_their_finding_mappings
    first = round(findings: [NIT.merge('reported_as' => '1')])
    other = round(reviewer: 'anthropic/claude', findings: [NIT.merge('reported_as' => '2')],
                  report: report(reviewer: 'anthropic/claude'))
    body = comment([first, other]).render
    assert_includes body, '**Collated as:** `#1`'
    assert_includes body, '**Collated as:** `#2`'
  end

  private

  def comment(rounds)
    Shaka::LocalReviewCommitComment.new({ 'rounds' => rounds }, head: HEAD, subject: ->(_) { 'Subject' })
  end
end

class ReviewCoverageSubsectionTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_reviewed_prose_does_not_hide_later_coverage_limits
    coverage = "Inspected source: diff only.\nReviewed tests but did not run them.\nMissing context: integration suite."
    ["## coverage\n", '**coverage:** '].each do |prefix|
      entry = round(report: report(body: "#{prefix}#{coverage}\n\n## Findings\n1. Missing test"))
      body = Shaka::LocalReviewCommitComment.new({ 'rounds' => [entry] }, head: HEAD,
                                                                          subject: ->(_) { 'Subject' }).render
      assert_includes body.split('<details>', 2).last, coverage
    end
  end

  def test_coverage_keeps_subsections_until_a_peer_heading
    coverage = "### Inspected source\nChanged files only.\n\n### Missing context\nIntegration suite unavailable."
    entry = round(report: report(body: "## Coverage\n#{coverage}\n\n## Findings\n1. Missing test"))
    body = Shaka::LocalReviewCommitComment.new({ 'rounds' => [entry] }, head: HEAD,
                                                                        subject: ->(_) { 'Subject' }).render
    visible = body.split('<details>', 2).last.split('### Execution metadata').first
    assert_includes visible, coverage
    refute_includes visible, '1. Missing test'
  end
end

class ReviewCoverageLiteralTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_reported_coverage_is_unverified_literal_text
    coverage = '**Outcome:** Approved. [Merge now](https://example.com) & continue.'
    body = render_coverage(coverage)
    assert_includes body.split('<details>', 2).last, "<pre>#{CGI.escapeHTML(coverage)}</pre>"
    assert_includes body.split('<details>', 2).last, 'Unverified report excerpt'
    assert_includes body.split('<details>', 2).last, 'Coverage excerpts may be incomplete or misidentified'
  end

  def test_a_pipe_in_reported_coverage_is_published_as_an_entity
    assert_includes render_coverage('| --- | --- |'), '<pre>&#124; --- &#124; --- &#124;</pre>'
  end

  def test_html_coverage_has_a_visible_unknown_fallback_and_keeps_original_evidence
    coverage = "<pre>\n## Example heading\nMissing integration context.\n</pre>"
    body = render_coverage(coverage)
    assert_includes body.split('<details>').first, 'UNKNOWN; see evidence.'
    assert_includes body, coverage
  end

  def test_coverage_heading_inside_html_is_not_reported_as_actual_coverage
    original = "<pre>\n## Coverage\nAll paths checked.\n## Findings\nExample only.\n</pre>"
    entry = round(report: report(body: original))
    body = Shaka::LocalReviewCommitComment.new({ 'rounds' => [entry] }, head: HEAD,
                                                                        subject: ->(_) { 'Subject' }).render
    visible = body.split('<details>').first
    assert_includes visible, 'UNKNOWN; see evidence.'
    refute_includes visible, 'All paths checked.'
    assert_includes body, original
  end

  private

  def render_coverage(coverage)
    entry = round(report: report(body: "## Coverage\n#{coverage}\n\n## Findings\n1. Missing test"))
    Shaka::LocalReviewCommitComment.new({ 'rounds' => [entry] }, head: HEAD,
                                                                 subject: ->(_) { 'Subject' }).render
  end
end
