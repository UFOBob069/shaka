# frozen_string_literal: true

require_relative 'local_review_comment_test'

# The published review names each provider review.provider_coverage expects that did not review the
# final commit, and a helper-written line names who did, which the hosted review reads.
class LocalReviewCoverageGapTest < Minitest::Test
  include LocalReviewCommentFixture

  GAP = { 'provider' => 'anthropic', 'reason' => Shaka::ReviewCoverage::UNAVAILABLE }.freeze
  BOTH = %w[anthropic openai].freeze

  def test_names_each_gap_and_its_reason_near_the_top
    header = loop_body('rounds' => [round], 'provider_coverage' => coverage([GAP])).split('**Reviewed commits:**').first

    assert_includes header, '**Review coverage gap:** no local review of this commit from `anthropic` ' \
                            "(#{Shaka::ReviewCoverage::UNAVAILABLE})."
  end

  def test_no_gaps_show_no_notice
    claude = round(reviewer: 'anthropic/claude', report: report(reviewer: 'anthropic/claude'))

    refute_includes loop_body('rounds' => [round, claude], 'provider_coverage' => coverage([])), 'coverage gap'
    refute_includes loop_body('rounds' => [round]), 'coverage gap'
  end

  # Selection chose Codex, whose run then failed, so the copied gaps never named openai.
  def test_a_listed_provider_missing_from_the_final_commit_is_a_gap_without_a_copied_reason
    claude = round(reviewer: 'anthropic/claude', report: report(reviewer: 'anthropic/claude'))
    body = loop_body('rounds' => [claude], 'provider_coverage' => coverage([]))

    assert_includes body, 'no local review of this commit from `openai` (reason not recorded).'
  end

  # Selection named anthropic as a gap, then Codex failed and a fallback Claude review ran.
  def test_ignores_a_stale_gap_for_a_provider_that_reviewed_the_commit
    claude = round(reviewer: 'anthropic/claude', report: report(reviewer: 'anthropic/claude'))
    body = loop_body('rounds' => [claude], 'provider_coverage' => coverage([GAP]))

    refute_includes body, 'from `anthropic`'
    assert_includes body, 'from `openai` (reason not recorded).'
  end

  def test_an_earlier_commit_review_does_not_cover_the_final_commit
    rounds = [round(EARLIER, reviewer: 'anthropic/claude', report: report(EARLIER, reviewer: 'anthropic/claude')),
              round(HEAD, findings: [])]
    rounds.last['report'] = report(HEAD, findings: 0)

    assert_includes loop_body('rounds' => rounds, 'provider_coverage' => coverage([GAP])), 'from `anthropic`'
  end

  def test_redacts_local_paths_from_gap_reasons
    gap = GAP.merge('reason' => 'cannot read /Users/alice/secret/key')
    body = loop_body('rounds' => [round], 'provider_coverage' => coverage([gap]))

    assert_includes body, '(cannot read [path]).'
    refute_includes body, 'alice'
  end

  def test_the_header_names_every_reviewer_of_the_final_commit
    claude = round(reviewer: 'anthropic/claude', report: report(reviewer: 'anthropic/claude'))
    body = loop_body('rounds' => [round, claude])

    marker = "<!-- shaka:local-reviewers #{HEAD} openai/codex anthropic/claude -->"
    assert body.start_with?("# Local Adversarial Review\n\n#{marker}\n\n"), body
  end

  private

  def coverage(gaps) = { 'providers' => BOTH, 'gaps' => gaps }

  def loop_body(content) = Shaka::LocalReviewLoopComment.new(content, subject: ->(_) { 'Subject' }).render
end
