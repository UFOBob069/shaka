# frozen_string_literal: true

require_relative 'local_review_batch_test'

class LocalReviewStatusTest < Minitest::Test
  include LocalReviewCommentFixture

  def test_explicit_open_and_decision_rows_name_the_reporters
    entries = [finding('open'), finding('decision_needed', note: 'Choose retries or manual recovery.')]
    body = presentation(entries)
    assert_includes body.split('<details>').first, '| Finding | Status | Reported by |'
    assert_includes body, '| Open | openai/codex |'
    assert_includes body, '| Needs your decision | openai/codex |'
  end

  def test_explicit_closed_findings_leave_the_visible_table_but_keep_the_evidence
    entries = [finding('dismissed', note: 'The existing validator rejects invalid input.'),
               finding('accepted', note: 'Manual recovery is acceptable.', decision: 'Maintainer chose it.')]
    body = presentation(entries)
    refute_includes body.split('<details>').first, 'Example finding'
    assert_includes body, 'The existing validator rejects invalid input.'
    assert_includes body, 'Maintainer chose it.'
  end

  def test_closure_requires_an_explanation_and_acceptance_requires_a_decision
    %w[dismissed accepted decision_needed].each do |status|
      assert_raises(Shaka::Error) { Shaka::LocalReviewFinding.new(finding(status), 'test') }
    end
    assert_raises(Shaka::Error) do
      Shaka::LocalReviewFinding.new(finding('accepted', note: 'Worth the risk.'), 'test')
    end
  end

  def test_accepted_or_dismissed_defects_do_not_trigger_the_unfixed_defect_cap
    %w[accepted dismissed].each do |status|
      entry = finding(status, note: 'Evidence or consequence.', decision: 'Maintainer decision.')
      content = { 'local_max_rounds' => 1, 'rounds' => [round(findings: [entry])] }
      body = Shaka::LocalReviewComment.render(content)
      refute_includes body, 'Loop bound reached'
      refute_includes body, '1 unfixed defect'
    end
  end

  private

  def finding(status, **extra)
    NIT.merge('id' => status, 'class' => 'defect', 'summary' => "Example finding #{status}",
              'disposition' => status).merge(extra.transform_keys(&:to_s))
  end

  def presentation(entries)
    entry = round(findings: entries, report: report(findings: entries.size))
    Shaka::LocalReviewLoopComment.new({ 'rounds' => [entry] }, subject: ->(_) { 'Subject' }).render
  end
end

class LocalReviewEarlierDispositionTest < Minitest::Test
  include LocalReviewLedgerSteps

  def test_an_earlier_batch_can_be_closed_without_inventing_a_new_reported_finding
    append(EARLIER, 'openai/codex', findings: 1)
    record([NIT.merge('class' => 'risk')])
    append(HEAD, 'openai/codex', findings: 0)
    closed = NIT.merge('class' => 'risk', 'disposition' => 'dismissed', 'note' => 'Existing validation covers this.')
    assert_equal [1], ledger.record!({ 'findings' => [closed] }, head: EARLIER)
    assert_equal 'dismissed', ledger.prior_findings.first.disposition
    assert_clean_latest_round
  end

  def assert_unassessed
    assert_equal 'documented', ledger.prior_findings.first.disposition
  end

  private :assert_unassessed

  def assert_clean_latest_round
    assert_empty ledger.rounds.last.fetch('findings', [])
  end

  private :assert_clean_latest_round

  def test_an_unknown_batch_leaves_the_ledger_unchanged
    append(HEAD, 'openai/codex', findings: 0)
    before = File.read(@path)
    assert_raises(Shaka::Error) { ledger.record!({ 'findings' => [] }, head: EARLIER) }
    assert_equal before, File.read(@path)
  end

  def test_an_earlier_batch_keeps_a_previously_recorded_intermediate_fix
    append(EARLIER, 'openai/codex', findings: 1)
    fixed = NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => FIX)
    record([fixed])
    append(HEAD, 'openai/codex', findings: 0)

    assert_equal [1], ledger.record!({ 'findings' => [fixed] }, head: EARLIER)
    assert_equal FIX, ledger.prior_findings.first.commit
  end

  def test_an_earlier_fix_needs_a_later_reviewed_revision
    append(EARLIER, 'openai/codex', findings: 1)
    record([NIT.merge('class' => 'defect')])
    append(HEAD, 'openai/codex', findings: 0)
    fixed = NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => FIX)
    assert_raises(Shaka::Error) { ledger.record!({ 'findings' => [fixed] }, head: EARLIER) }
    assert_unassessed
    assert_equal [1], ledger.record!({ 'findings' => [fixed.merge('commit' => HEAD)] }, head: EARLIER)
  end
end
