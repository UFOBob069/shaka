# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'local_review_comment_test'
require 'tmpdir'
require 'shaka/local_review'

# A ledger outside any checkout, with rounds whose reports close with real attestations.
module LocalReviewLedgerSteps
  include LocalReviewCommentFixture

  BASE = 'd' * 40
  FIX = 'e' * 40

  def setup
    @directory = Dir.mktmpdir('shaka-batch')
    @path = File.join(@directory, 'ledger.json')
  end

  def teardown
    super
    FileUtils.rm_rf(@directory)
  end

  private

  def ledger(settings = nil) = Shaka::LocalReviewLedger.new(@path).tap { |ledger| ledger.settings = settings }

  def append(head, reviewer, findings:, settings: nil)
    ledger(settings).append!(base: BASE, round: round_entry(head, reviewer, findings))
  end

  def round_entry(head, reviewer, findings)
    { 'head' => head, 'reviewer' => reviewer, 'report' => report(head, reviewer:, findings:) }
  end

  def record(findings, **extra) = ledger.record!({ 'findings' => findings }.merge(extra.transform_keys(&:to_s)))

  # Two reviewers read one commit, record a finding, then read it again under changed settings.
  def review_twice
    %w[openai/codex anthropic/claude].each { |reviewer| append(EARLIER, reviewer, findings: 1, settings: 'a' * 64) }
    record([NIT.merge('reviewers' => { 'openai/codex' => '1', 'anthropic/claude' => '1' })])
    %w[openai/codex anthropic/claude].each { |reviewer| append(EARLIER, reviewer, findings: 0, settings: 'c' * 64) }
  end

  def fixed(reviewers)
    numbers = reviewers.to_h { |reviewer| [reviewer, '1'] }
    NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => FIX, 'reviewers' => numbers)
  end
end

# Several reviewers read one commit before its findings are recorded and fixed together.
class LocalReviewBatchLedgerTest < Minitest::Test
  include LocalReviewLedgerSteps

  def test_another_reviewer_joins_the_last_commit_before_findings_are_recorded
    append(EARLIER, 'openai/codex', findings: 1)
    ledger.check_next!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude')

    error = assert_raises(Shaka::Error) { ledger.check_next!(base: BASE, head: EARLIER, reviewer: 'OpenAI/Codex') }
    assert_includes error.message, 'Round 1 already reviewed'
  end

  # Break caught: a new head started while one reviewer's findings were still unrecorded.
  def test_a_new_head_waits_for_every_reviewer_of_the_last_commit
    append(EARLIER, 'openai/codex', findings: 0)
    append(EARLIER, 'anthropic/claude', findings: 1)

    error = assert_raises(Shaka::Error) { ledger.check_next!(base: BASE, head: HEAD, reviewer: 'openai/codex') }
    assert_includes error.message, 'Record round 2'
    record([NIT.merge('reviewers' => { 'anthropic/claude' => '1' })])
    ledger.check_next!(base: BASE, head: HEAD, reviewer: 'openai/codex')
  end

  # Break caught: the next head skipped a fix that only the second reviewer's round recorded.
  def test_the_next_head_must_hold_fixes_from_every_reviewer_of_the_last_commit
    append(EARLIER, 'openai/codex', findings: 0)
    append(EARLIER, 'anthropic/claude', findings: 1)
    record([fixed(['anthropic/claude'])])

    assert_equal [FIX], ledger.recorded_batch_fixes
  end

  # Break caught: a reviewer joining the last commit was shown no commits since the one before.
  def test_a_reviewer_joining_the_last_commit_reads_from_the_commit_before
    append(EARLIER, 'openai/codex', findings: 1)
    record([NIT])
    append(HEAD, 'openai/codex', findings: 1)

    assert_equal EARLIER, ledger.previous_head(HEAD)
    assert_equal ['F1'], ledger.prior_findings.map(&:id)
  end

  # Break caught: a reviewer that finished after a newer commit was appended split its batch apart.
  def test_a_late_round_cannot_rejoin_an_older_commit
    append(EARLIER, 'openai/codex', findings: 0)
    append(HEAD, 'openai/codex', findings: 0)

    error = assert_raises(Shaka::Error) { append(EARLIER, 'anthropic/claude', findings: 0) }
    assert_includes error.message, 'Round 1 already reviewed'
    assert_includes assert_raises(Shaka::Error) { append(HEAD, 'openai/codex', findings: 0) }.message, 'Round 2'
  end

  # Break caught: a new head landed after a late reviewer of the old head, leaving its findings unrecorded.
  def test_a_new_head_cannot_land_after_an_unrecorded_late_round
    append(EARLIER, 'openai/codex', findings: 0)
    ledger.check_next!(base: BASE, head: HEAD, reviewer: 'openai/codex')
    append(EARLIER, 'anthropic/claude', findings: 1)

    assert_includes assert_raises(Shaka::Error) { append(HEAD, 'openai/codex', findings: 0) }.message, 'Record round 2'
  end

  # Break caught: a fix recorded on the old head while the new head's review ran was never checked
  # against the new head's history.
  def test_an_append_refuses_a_ledger_that_changed_under_it
    append(EARLIER, 'openai/codex', findings: 0)
    snapshot = ledger.snapshot(HEAD)
    append(EARLIER, 'anthropic/claude', findings: 1)
    record([fixed(['anthropic/claude'])])

    error = assert_raises(Shaka::Error) do
      ledger.append!(base: BASE, round: round_entry(HEAD, 'openai/codex', 0), snapshot:)
    end
    assert_includes error.message, 'changed while this round ran'
  end

  # Break caught: two reviewers started on one empty ledger with different bases mixed their diffs.
  def test_an_append_rechecks_the_base
    append(EARLIER, 'openai/codex', findings: 0)
    round = round_entry(EARLIER, 'anthropic/claude', 0)

    error = assert_raises(Shaka::Error) { ledger.append!(base: 'f' * 40, round:) }
    assert_includes error.message, 'use a new ledger'
  end

  # Break caught: a settings re-review joined the earlier batch on its commit, so recording it
  # rewrote findings that batch had already triaged.
  def test_a_settings_rereview_is_a_new_batch_on_the_same_commit
    review_twice

    assert_equal [3, 4], ledger.record!({ 'findings' => [] })
    assert_equal([1, 1, 0, 0], ledger.rounds.map { |round| round.fetch('findings').size })
  end

  # Break caught: a third batch under the first settings would have split that batch's rounds apart.
  def test_a_settings_rereview_cannot_return_to_earlier_settings
    review_twice
    ledger.record!({ 'findings' => [] })

    error = assert_raises(Shaka::Error) { append(EARLIER, 'openai/codex', findings: 0, settings: 'a' * 64) }
    assert_includes error.message, 'reviewed under other settings'
  end

  # Break caught: a later record of the commit reaches only its newest batch, stranding an open finding.
  def test_a_settings_rereview_waits_for_open_findings_to_be_settled
    append(EARLIER, 'openai/codex', findings: 1, settings: 'a' * 64)
    record([NIT.merge('disposition' => 'open')])

    error = assert_raises(Shaka::Error) { append(EARLIER, 'openai/codex', findings: 0, settings: 'c' * 64) }
    assert_includes error.message, 'Settle finding F1'
  end

  # Break caught: a re-review of a commit whose recorded fix is in a later commit could never publish.
  def test_a_settings_rereview_waits_for_a_recorded_fix_to_be_reviewed
    append(EARLIER, 'openai/codex', findings: 1, settings: 'a' * 64)
    record([fixed(['openai/codex'])])

    error = assert_raises(Shaka::Error) { append(EARLIER, 'openai/codex', findings: 0, settings: 'c' * 64) }
    assert_includes error.message, 'review its fix'
  end

  # Break caught: a reviewer without recorded settings joined a batch with them, or the reverse,
  # and split one commit's triage in two.
  def test_reviewers_of_one_commit_share_their_settings
    append(EARLIER, 'openai/codex', findings: 0)

    error = assert_raises(Shaka::Error) { append(EARLIER, 'anthropic/claude', findings: 0, settings: 'a' * 64) }
    assert_includes error.message, 'reviewed under other settings'
  end

  # Break caught: two reviewers finishing together each wrote the ledger they had read, losing a round.
  def test_concurrent_appends_keep_every_round
    readers = [ledger, ledger]
    readers.each(&:rounds)
    readers.zip(%w[openai/codex anthropic/claude]).map do |reader, reviewer|
      Thread.new { reader.append!(base: BASE, round: round_entry(EARLIER, reviewer, 0)) }
    end.each(&:join)

    assert_equal %w[openai/codex anthropic/claude].sort, ledger.rounds.map { |round| round['reviewer'] }.sort
  end
end

# A published comment lists every reviewer of a commit together.
class LocalReviewBatchCommentTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_renders_two_reviewers_of_one_commit_and_closes_with_the_last
    body = render('rounds' => [clean('openai/codex'), clean('anthropic/claude')])

    assert_includes body, '**Outcome:** No open findings; closed and optional findings are in history.'
    assert body.end_with?("REVIEWED #{HEAD} BY anthropic/claude EFFORT UNKNOWN FINDINGS 0\n")
  end

  # Break caught: a clean last reviewer hid its sibling's documented findings.
  def test_outcome_counts_every_reviewer_of_the_last_commit
    body = render('rounds' => [round, clean('anthropic/claude')])

    assert_includes body, 'No open findings; closed and optional findings are in history.'
  end

  # Break caught: a finding both reviewers of one commit reported read as returning after its fix.
  def test_both_reviewers_of_a_commit_may_report_a_finding_later_fixed
    fixed = NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => HEAD)
    first = round(EARLIER, report: report(EARLIER), findings: [fixed])
    second = round(EARLIER, reviewer: 'anthropic/claude', findings: [fixed],
                            report: report(EARLIER, reviewer: 'anthropic/claude'))

    refute_includes render('rounds' => [first, second, clean('openai/codex')]), 'returned after its fix'
  end

  # Break caught: two reviewers of one commit showed the loop bound as if two commits were reviewed.
  def test_the_loop_bound_counts_commits
    defect = NIT.merge('class' => 'defect')
    body = render('rounds' => [round(findings: [defect]), clean('anthropic/claude')], 'local_max_rounds' => 2)

    refute_includes body, 'Loop bound reached'
  end

  # Break caught: a commit's reviews gave no path from each reviewer's findings to one triage.
  def test_a_commit_with_several_reviewers_shows_each_mapping_then_one_triage
    body = render('rounds' => [round(findings: [NIT.merge('reported_as' => '1')]), claude_reporting('2')])

    %w[1 2].each { |number| assert_includes body, "**Collated as:** `##{number}` → `F1`" }
    assert_includes body, "## Findings\n\n**Triage of `aaaaaaa`** · openai/codex: 1 finding · " \
                          "anthropic/claude: 1 finding\n\n- `F1` nit: Missing test — documented nit — " \
                          'reporters: openai/codex `#1`, anthropic/claude `#2`'
    assert_operator body.index('## Findings'), :<, body.index('<details>')
    assert_equal 1, body.scan('- `F1` nit').size
  end

  # Break caught: the outcome counted a finding both reviewers reported once per reviewer.
  def test_outcome_counts_a_shared_finding_once
    claude = round(reviewer: 'anthropic/claude', report: report(HEAD, reviewer: 'anthropic/claude'))

    assert_includes render('rounds' => [round, claude]),
                    'No open findings; closed and optional findings are in history.'
  end

  # Break caught: a content file gave one shared finding two outcomes, and the triage showed only one.
  def test_refuses_two_outcomes_for_one_finding_of_a_commit
    fixed = NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => EARLIER)
    claude = round(reviewer: 'anthropic/claude', report: report(HEAD, reviewer: 'anthropic/claude'), findings: [fixed])
    error = assert_raises(Shaka::Error) { render('rounds' => [round, claude]) }

    assert_includes error.message, 'Finding F1 has two outcomes'
  end

  # Break caught: a lone reviewer's findings appeared only inside its collapsed report, and a clean
  # commit did not show which reviewers read it.
  def test_lists_every_commit_before_the_reports
    rounds = [round(EARLIER, report: report(EARLIER)), clean('openai/codex'), clean('anthropic/claude')]
    body = render('rounds' => rounds)
    findings = body[body.index('## Findings')...body.index('<details>')]

    assert_includes findings, "**Triage of `bbbbbbb`** · openai/codex: 1 finding\n\n- `F1` nit"
    assert_includes findings, '**Triage of `aaaaaaa`** · openai/codex: 0 findings · anthropic/claude: 0 findings'
  end

  def test_refuses_one_reviewer_reading_a_commit_twice
    error = assert_raises(Shaka::Error) { render('rounds' => [clean('openai/codex'), clean('OpenAI/Codex')]) }

    assert_includes error.message, 'same reviewer'
  end

  def test_refuses_a_commit_whose_rounds_are_split_apart
    rounds = [clean('openai/codex'), clean('openai/codex', EARLIER), clean('anthropic/claude')]

    assert_includes assert_raises(Shaka::Error) { render('rounds' => rounds) }.message, 'listed together'
  end

  # Break caught: a fix recorded by the first reviewer of the last commit was never reviewed.
  def test_refuses_a_fix_recorded_anywhere_in_the_last_commit
    fixed = round(findings: [NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => EARLIER)])

    error = assert_raises(Shaka::Error) { render('rounds' => [fixed, clean('anthropic/claude')]) }
    assert_includes error.message, 'Round 1 records fixes no later round reviewed'
  end

  private

  def claude_reporting(number)
    round(reviewer: 'anthropic/claude', report: report(HEAD, reviewer: 'anthropic/claude'),
          findings: [NIT.merge('reported_as' => number)])
  end

  def clean(reviewer, head = HEAD)
    round(head, reviewer:, report: report(head, body: "no findings\n", reviewer:, findings: 0), findings: [])
  end
end
