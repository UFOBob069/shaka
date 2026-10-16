# frozen_string_literal: true

require_relative 'local_review_assessment_test'

# Runs `shaka review export` on the test ledger.
module LocalReviewExportSteps
  include SyntheticReviewAssessment

  private

  def export_text
    output, = capture_io { assert_equal 0, Shaka::LocalReview.run(['export', '--ledger', @path]) }
    output
  end

  def exported = JSON.parse(export_text)
  def exported_round = exported['rounds'].first
  def exported_judgments(key) = exported['assessments'].map { |entry| entry.values_at('id', key) }
end

# The synthetic chains of internal/review-outcomes.md, read back through the export.
class LocalReviewExportTest < Minitest::Test
  include LocalReviewExportSteps

  def test_accepted_harmful_removal_exports_every_step_of_its_chain
    accepted_retry_removal
    assess_harmful_then_reverted
    first = exported_round
    accepted = first['findings'].first
    assert_equal 'fixed', accepted['disposition']
    assert_includes accepted['note'], 'Accepted removal of retry'
    assert_includes first['report_text'], "REVIEWED #{EARLIER}"
    assert_equal [%w[A1 action_required], %w[A2 none]], exported_judgments('attention')
  end

  def test_each_synthetic_case_keeps_its_judgments_without_derived_labels
    reviewed_finding
    ledger.assess!(assessment(problem: 'confirmed', remedy: 'excessive', implementation: 'correct'))
    ledger.assess!(assessment('A2', remedy: 'supported', implementation: 'defective', attention: 'none'))
    ledger.assess!(assessment('A3', supersedes: %w[A1 A2], remedy: 'supported', implementation: 'correct',
                                    action: { 'taken' => 'replaced', 'attribution' => 'uncertain' }, attention: 'none'))
    assert_equal assessments, exported['assessments']
    refute_includes export_text, 'reward'
  end

  def test_declined_wrong_claim_and_earlier_triage_are_both_exported
    reviewed_finding
    decline_wrong_claim
    triage = exported_round.values_at('earlier_findings', 'findings').map { |list| list.flatten.first['disposition'] }
    assert_equal %w[documented dismissed], triage
    refute exported['assessments'].first['action'].key?('commits')
  end

  def test_repeated_exports_are_identical_and_add_no_timestamps
    accepted_retry_removal
    ledger.assess!(assessment)
    first = export_text
    assert_equal first, export_text
    assert_equal JSON.generate(saved).scan('recorded_at').size, first.scan('recorded_at').size
  end

  def test_legacy_ledger_exports_without_a_version_or_invented_attribution
    reviewed_finding
    make_legacy
    document = exported
    assert_equal [1, nil], document.values_at('export_version', 'ledger_version')
    refute document['rounds'].first['findings'].first.key?('by')
  end

  def test_a_newer_ledger_is_refused
    reviewed_finding
    File.write(@path, JSON.generate(saved.merge('version' => 99)))
    _, error = capture_io { assert_equal 1, Shaka::LocalReview.run(['export', '--ledger', @path]) }
    assert_match(/newer Shaka/, error)
  end

  private

  def decline_wrong_claim
    record([NIT.merge('reported_as' => '1', 'disposition' => 'dismissed', 'note' => 'Refuted by the guard.')])
    ledger.assess!(assessment(problem: 'refuted', remedy: 'incorrect', action: { 'taken' => 'not_attempted' },
                              attention: 'none'))
  end

  def assess_harmful_then_reverted
    harmful = assessment(problem: 'refuted', implementation: 'correct', revision: HEAD,
                         action: { 'taken' => 'as_proposed', 'commits' => [HEAD], 'attribution' => 'direct' })
    ledger.assess!(harmful)
    ledger.assess!(harmful.merge('id' => 'A2', 'supersedes' => ['A1'], 'attention' => 'none',
                                 'action' => { 'taken' => 'reverted', 'commits' => [FIX], 'attribution' => 'direct' }))
  end
end

# A report the export cannot read is marked in its round, and every other round still exports.
class LocalReviewExportReportTest < Minitest::Test
  include LocalReviewExportSteps

  def test_a_missing_or_changed_report_is_marked_and_the_rest_still_exports
    accepted_retry_removal
    damage_kept_reports
    rounds = exported['rounds']
    assert_equal 2, rounds.size
    rounds.zip([/missing/, /changed/]).each do |round, reason|
      assert_match reason, round['report_unavailable']
      refute round.key?('report_text')
    end
  end

  def test_a_report_that_is_not_utf8_is_marked_unavailable
    accepted_retry_removal
    report = ledger.rounds.first.fetch('report')
    File.binwrite(report, "\xFF".b)
    rewrite_round_hash(report)
    assert_match(/not valid UTF-8/, exported_round['report_unavailable'])
  end

  def test_relocated_ledger_finds_its_kept_reports
    accepted_retry_removal
    recorded = ledger.rounds.map { |round| round.fetch('report') }
    move_ledger_alone
    rounds = exported['rounds']
    assert(rounds.all? { |round| round.key?('report_text') })
    assert_equal(recorded, rounds.map { |round| round['report'] })
  end

  def test_an_unreadable_report_is_marked_and_the_rest_still_exports
    accepted_retry_removal
    File.chmod(0o000, ledger.rounds.first.fetch('report'))
    rounds = exported['rounds']
    assert_match(/could not be read/, rounds.first['report_unavailable'])
    assert rounds.last.key?('report_text')
  end

  private

  def rewrite_round_hash(report)
    changed = saved
    changed['rounds'].first['report_sha256'] = Digest::SHA256.file(report).hexdigest
    File.write(@path, JSON.generate(changed))
  end

  # Leaves the kept copies beside the moved ledger as the only ones.
  def move_ledger_alone
    Array(@reports).each { |path| FileUtils.rm_f(path) }
    relocate_bundle
    FileUtils.rm_rf(File.join(@directory, 'reports'))
  end

  def damage_kept_reports
    FileUtils.rm_f(ledger.rounds.first.fetch('report'))
    File.write(ledger.rounds.last.fetch('report'), 'edited')
  end
end
