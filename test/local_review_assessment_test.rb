# frozen_string_literal: true

require_relative 'local_review_batch_test'
require_relative 'local_review_commit_publish_test'

# Invented identities, evidence and revisions: these chains make no claims about a real PR.
module SyntheticReviewAssessment
  include LocalReviewLedgerSteps

  def assessment(id = 'A1', **fields)
    { 'id' => id, 'finding' => 'F1', 'remedy' => 'harmful', 'attention' => 'action_required',
      'by' => { 'name' => 'example-maintainer', 'role' => 'maintainer' }, 'rationale' => 'Synthetic regression.' }
      .merge(fields.transform_keys(&:to_s))
  end

  def reviewed_finding
    append(EARLIER, 'openai/codex', findings: 1)
    record([NIT.merge('reported_as' => '1')])
  end

  def accepted_retry_removal
    append(EARLIER, 'openai/codex', findings: 1)
    record([NIT.merge('class' => 'defect', 'disposition' => 'fixed', 'commit' => HEAD,
                      'note' => 'Accepted removal of retry to prevent duplicate writes.', 'reported_as' => '1')])
    append(HEAD, 'openai/codex', findings: 0)
  end

  def first_round = ledger.rounds.first
  def current_findings = first_round.fetch('findings')
  def newest_finding = ledger.rounds.last.fetch('findings').first
  def assessments = saved.fetch('assessments')
  def judgments = Shaka::LocalReviewAssessments.new(saved)

  def original_recommendation
    { 'head' => EARLIER, 'reviewer' => 'openai/codex', 'reported_as' => '1' }
  end

  def merged_finding
    append(HEAD, 'openai/codex', findings: 1)
    record([NIT.merge('id' => 'F2')])
    ledger.assess!(assessment('A2', finding: 'F2', supersedes: ['A1'], attention: 'none'))
  end

  def make_legacy
    legacy = saved
    legacy.delete('version')
    legacy['rounds'].first['findings'] = [NIT]
    File.write(@path, JSON.generate(legacy))
  end

  def relocate_bundle
    moved = File.join(@directory, 'moved')
    FileUtils.mkdir_p(moved)
    FileUtils.cp(@path, File.join(moved, 'ledger.json'))
    FileUtils.cp_r(File.join(@directory, 'reports'), moved)
    @path = File.join(moved, 'ledger.json')
  end

  def drop_assessed_reference
    changed = saved
    changed['rounds'].first['findings'].first['id'] = 'F2'
    File.write(@path, JSON.generate(changed))
  end

  def concurrent(values, &)
    children = values.map do |value|
      fork do
        yield(value)
        exit! 0
      end
    end
    children.each { |pid| assert_predicate Process.wait2(pid).last, :success? }
  end

  def saved = JSON.parse(File.read(@path))

  # The comment as published when `head` was the newest reviewed commit.
  def view(head = HEAD)
    content = saved
    last = content.fetch('rounds').rindex { |round| round.fetch('head') == head }
    content['rounds'] = content.fetch('rounds').take(last + 1)
    Shaka::LocalReviewLoopComment.new(content, subject: ->(_) { 'Synthetic change' }).render
  end
end

class LocalReviewAssessmentTest < Minitest::Test
  include LocalReviewLedgerSteps
  include SyntheticReviewAssessment

  def test_retriage_keeps_the_previous_decision_and_actor
    reviewed_finding
    first = current_findings
    assert first.first['recorded_at']
    record([NIT.merge('reported_as' => '1', 'disposition' => 'dismissed', 'note' => 'The test already exists.')],
           by: { 'name' => 'owner', 'role' => 'task_owner' })
    assert_equal [first], first_round['earlier_findings']
    assert_equal 'owner', current_findings.first['by']['name']
  end

  def test_identical_retriage_and_usage_enrichment_preserve_the_timestamp_and_actor
    append(EARLIER, 'openai/codex', findings: 1)
    record([NIT], by: { 'name' => 'owner', 'role' => 'task_owner' })
    first = first_round
    record([NIT])
    ledger.record!({ 'tokens' => '19' })
    assert_equal first['findings'], current_findings
    assert_nil first_round['earlier_findings']
  end

  def test_assessment_retry_is_a_noop_and_never_rewrites_a_judgment
    reviewed_finding
    ledger.assess!(assessment)
    original = File.read(@path)
    ledger.assess!(assessment)
    assert_equal original, File.read(@path)
    assert_raises(Shaka::Error) { ledger.assess!(assessment.merge('remedy' => 'supported')) }
  end

  def test_concurrent_assessments_and_retries_are_neither_lost_nor_duplicated
    reviewed_finding
    concurrent(%w[A1 A2 A1 A2]) { |id| ledger.assess!(assessment(id)) }
    assert_equal %w[A1 A2], assessments.map { |item| item['id'] }.sort
  end

  def test_concurrent_retriage_keeps_every_distinct_decision
    reviewed_finding
    concurrent(%w[one two]) { |note| record([NIT.merge('note' => note)]) }
    round = first_round
    notes = (round['earlier_findings'].flatten + round['findings']).filter_map { |item| item['note'] }
    assert_equal %w[one two], notes.sort
  end

  def test_assessed_recommendation_mapping_cannot_be_moved_without_superseding_it
    reviewed_finding
    ref = { 'head' => EARLIER, 'reviewer' => 'openai/codex', 'reported_as' => '1' }
    ledger.assess!(assessment(recommendation: ref))
    assert_raises(Shaka::Error) { record([NIT.merge('reported_as' => '2')]) }
    merged_finding
    ledger.record!({ 'findings' => [NIT.merge('id' => 'F2')] }, head: EARLIER)
    assert_equal 'F2', current_findings.first['id']
  end

  def test_legacy_triage_stays_unknown_and_is_kept_on_its_first_replacement
    reviewed_finding
    make_legacy
    record([NIT.merge('note' => 'Optional')])
    prior = first_round['earlier_findings'].first.first
    refute prior.key?('by')
    refute prior.key?('recorded_at')
    assert_equal 'documented', prior['disposition']
  end
end

class LocalReviewAssessmentValidationTest < Minitest::Test
  include LocalReviewLedgerSteps
  include SyntheticReviewAssessment

  def test_malformed_judgments_dates_references_and_attribution_leave_no_record
    reviewed_finding
    bad_entries.each do |entry|
      assert_raises(Shaka::Error, entry.inspect) { ledger.assess!(entry) }
    end
    refute saved.key?('assessments')
  end

  def test_no_unknown_outcome_is_inferred_and_observed_time_is_separate_from_recording_time
    reviewed_finding
    ledger.assess!(assessment.except('remedy', 'attention').merge('problem' => 'uncertain',
                                                                  'observed_at' => '2026-09-01'))
    entry = assessments.first
    assert_equal '2026-09-01', entry['observed_at']
    assert entry['recorded_at']
    refute entry.key?('remedy')
    refute entry.key?('implementation')
  end

  def test_assess_cli_appends_and_rejects_unsupported_arguments
    reviewed_finding
    input = File.join(@directory, 'assessment.json')
    File.write(input, JSON.generate(assessment))
    output, = capture_io do
      assert_equal 0, Shaka::LocalReview.run(['assess', '--ledger', @path, '--content-file', input])
    end
    assert_equal 'A1', JSON.parse(output)['assessment']
  end

  private

  def bad_entries
    [{ 'problem' => 'true' }, { 'observed_at' => '2026-02-30' }, { 'observed_at' => 'yesterday' },
     { 'recorded_at' => '2026-09-01' }, { 'evidence' => ['/tmp/private'] }, { 'evidence' => ['https://u:p@host'] },
     { 'supersedes' => ['A1'] }, { 'finding' => 'absent' }, { 'by' => { 'name' => 'x', 'role' => 'god' } },
     { 'rationale' => "two\nlines" }, { 'action' => { 'taken' => 'not_attempted', 'commits' => [HEAD] } },
     { 'action' => { 'taken' => 'as_proposed', 'attribution' => 'certain' } }, { 'attention' => nil },
     { 'reward' => 1 }, { 'recommendation' => { 'head' => HEAD, 'reviewer' => 'openai/codex', 'reported_as' => '1' } }]
      .map { |fields| assessment.merge(fields) } + [assessment.except('remedy', 'attention')]
  end
end

class LocalReviewAssessmentMeaningTest < Minitest::Test
  include LocalReviewLedgerSteps
  include SyntheticReviewAssessment

  def test_accepted_retry_removal_then_refuted_harmful_remedy_and_correction
    accepted_retry_removal
    harmful = assessment(problem: 'refuted', implementation: 'correct', revision: HEAD,
                         action: { 'taken' => 'as_proposed', 'commits' => [HEAD], 'attribution' => 'direct' })
    ledger.assess!(harmful)
    active = view.split('<details>').first
    assert_includes active, 'harmful'
    assert_includes active, 'needs attention'
    ledger.assess!(harmful.merge('id' => 'A2', 'supersedes' => ['A1'], 'attention' => 'none',
                                 'action' => { 'taken' => 'reverted', 'commits' => [FIX], 'attribution' => 'direct' }))
    assert_settled_chain
  end

  def test_good_remedy_bad_implementation_and_changed_requirements_are_distinct
    reviewed_finding
    ledger.assess!(assessment(remedy: 'supported', implementation: 'defective'))
    ledger.assess!(assessment('A2', supersedes: ['A1'], remedy: 'supported', implementation: 'correct',
                                    action: { 'taken' => 'replaced', 'attribution' => 'uncertain' }, attention: 'none',
                                    rationale: 'Requirements changed; the original recommendation remains supported.'))
    assert_equal 'supported', assessments.last['remedy']
    assert_equal 'uncertain', assessments.last['action']['attribution']
  end

  def test_a_real_problem_can_have_an_excessive_remedy_and_a_wrong_claim_can_be_declined
    reviewed_finding
    ledger.assess!(assessment(problem: 'confirmed', remedy: 'excessive', implementation: 'correct'))
    ledger.assess!(assessment('A2', supersedes: ['A1'], problem: 'refuted', remedy: 'incorrect',
                                    action: { 'taken' => 'not_attempted' }, attention: 'none'))
    refute assessments.last['action'].key?('commits')
    assert_equal 2, assessments.size
  end

  def test_conflicts_have_no_automatic_winner_and_need_an_explicit_correction
    reviewed_finding
    ledger.assess!(assessment(attention: 'none'))
    ledger.assess!(assessment('A2', remedy: 'supported', attention: 'none'))
    history = judgments
    assert history.conflict?('F1')
    ledger.assess!(assessment('A3', supersedes: %w[A1 A2], attention: 'none'))
    refute judgments.conflict?('F1')
  end

  def test_competing_remedies_are_separate_but_problem_validity_is_shared
    append(EARLIER, 'openai/codex', findings: 1)
    append(EARLIER, 'anthropic/claude', findings: 1)
    record([NIT.merge('reviewers' => { 'openai/codex' => '1', 'anthropic/claude' => '2' })])
    assess_remedies('confirmed')
    refute judgments.conflict?('F1')
    ledger.assess!(assessment('A3', problem: 'refuted', attention: 'none'))
    assert judgments.conflict?('F1')
  end

  private

  def assess_remedies(problem)
    %w[openai/codex anthropic/claude].each_with_index do |reviewer, index|
      ledger.assess!(assessment("A#{index + 1}", problem:, attention: 'none',
                                                 remedy: index.zero? ? 'harmful' : 'supported',
                                                 recommendation: { 'head' => EARLIER, 'reviewer' => reviewer,
                                                                   'reported_as' => (index + 1).to_s }))
    end
  end

  def assert_settled_chain
    body = view
    refute_includes body.split('<details>').first, 'harmful'
    assert_includes body, 'Accepted removal of retry'
    assert_includes body, 'superseded'
    assert_includes body, 'reverted'
    assert_equal "REVIEWED #{HEAD} BY openai/codex EFFORT UNKNOWN FINDINGS 0", body.lines.last.strip
  end
end

class LocalReviewAssessmentPresentationTest < Minitest::Test
  include SyntheticReviewAssessment

  class MergedTimeline < LocalReviewCommitPublishTest::Timeline
    def api(path)
      return { 'head' => { 'sha' => LocalReviewCommentFixture::HEAD }, 'state' => 'closed', 'merged' => true } if
        path.end_with?('/pulls/7')

      super
    end
  end

  def test_post_merge_assessment_keeps_review_attestation_and_updates_the_managed_comment
    accepted_retry_removal
    ledger.assess!(assessment)
    github = MergedTimeline.new
    Shaka::LocalReviewPublisher.new(saved, github, 'o/r').publish
    assert_published_assessment(github.replies.last.last)
  end

  def test_assessment_data_cannot_inject_disclosures_or_markdown_actions
    reviewed_finding
    ledger.assess!(assessment(rationale: '</code></details> [merge now](https://example.com) | x'))
    body = view(EARLIER)
    assert_equal 3, body.scan('<details>').size
    assert_includes CGI.unescapeHTML(body), '</code></details> [merge now](https://example.com) | x'
    refute_includes body.split('<details>').first, '[merge now](https://example.com)'
  end

  def test_a_later_assessment_appears_once_in_the_current_outcome
    accepted_retry_removal
    ledger.assess!(assessment)
    visible = view.split('<details>').first
    assert_equal 1, visible.scan('**Outcome:**').size
    assert_includes visible, 'harmful'
  end

  def test_orphaned_assessment_stays_visible_if_an_older_writer_dropped_its_reference
    reviewed_finding
    ledger.assess!(assessment(attention: 'none'))
    drop_assessed_reference
    assert_includes view(EARLIER).split('<details>').first, 'Assessment reference unavailable'
    assert_includes view(EARLIER), 'reference unavailable'
  end

  def test_bundled_history_survives_original_report_cleanup_and_directory_move
    accepted_retry_removal
    ledger.assess!(assessment)
    Array(@reports).each { |path| FileUtils.rm_f(path) }
    relocate_bundle
    assert_includes view, 'Synthetic regression'
    assert_equal 'harmful', assessments.first['remedy']
  end

  def test_preserved_triage_is_rendered_without_inventing_legacy_attribution
    reviewed_finding
    make_legacy
    record([NIT.merge('note' => 'The owner deferred this optional suggestion.')])
    body = view(EARLIER)
    assert_includes body, 'Preserved triage'
    refute_includes body, 'triaged by <code>UNKNOWN</code>'
    assert_includes body, '&quot;disposition&quot;: &quot;documented&quot;'
  end

  private

  def assert_published_assessment(body)
    assert_includes body.split('<details>').first, 'harmful'
    assert_equal "REVIEWED #{HEAD} BY openai/codex EFFORT UNKNOWN FINDINGS 0", body.lines.last.strip
  end
end

class LocalReviewAssessmentMappingTest < Minitest::Test
  include SyntheticReviewAssessment

  def test_solo_report_numbers_cannot_name_two_recommendations
    append(EARLIER, 'openai/codex', findings: 2)
    first = NIT.merge('reported_as' => '1')
    assert_raises(Shaka::Error) { record([first, first.merge('id' => 'F2')]) }
    record([first, first.merge('id' => 'F2', 'reported_as' => '2')])
    assert_equal(%w[1 2], current_findings.map { |item| item['reported_as'] })
  end

  def test_superseded_reference_resolves_through_preserved_triage
    reviewed_finding
    ledger.assess!(assessment(recommendation: original_recommendation))
    merged_finding
    ledger.record!({ 'findings' => [NIT.merge('id' => 'F2')] }, head: EARLIER)
    history = judgments
    entry = history.entries.first
    assert history.historically_available?(entry)
    refute history.available?(entry)
  end
end

class LocalReviewAssessmentFormatTest < Minitest::Test
  include SyntheticReviewAssessment

  def test_newer_or_malformed_versions_cannot_lose_judgments_at_publication
    reviewed_finding
    [4, '3', -1, 2.5].each do |version|
      content = saved.merge('version' => version)
      assert_raises(Shaka::Error) { Shaka::LocalReviewBundle.resolve(content, @directory) }
      assert_raises(Shaka::Error) { Shaka::LocalReviewComment.new(content) }
    end
  end
end

class LocalReviewOrphanProgressTest < Minitest::Test
  include SyntheticReviewAssessment

  def test_an_already_missing_reference_does_not_block_usage_or_unrelated_triage
    reviewed_finding
    ledger.assess!(assessment)
    drop_assessed_reference
    ledger.record!({ 'tokens' => '25' })
    append(HEAD, 'openai/codex', findings: 1)
    record([NIT.merge('id' => 'F3')])
    assert_includes view.split('<details>').first, 'Assessment reference unavailable'
    assert_equal 'F3', newest_finding['id']
  end
end

class LocalReviewTriagePresentationTest < Minitest::Test
  include SyntheticReviewAssessment

  def test_each_heads_metadata_is_published_once_while_its_ledger_history_is_retained
    retriage(EARLIER, 'F1', 'EarlierOwner')
    retriage(HEAD, 'F2', 'CurrentOwner')
    assert_equal 1, view.scan('EarlierOwner').size
    assert_equal 1, view.scan('CurrentOwner').size
    assert_equal(2, ledger.rounds.sum { |round| round.fetch('earlier_findings').size })
  end

  private

  def retriage(head, id, name)
    append(head, 'openai/codex', findings: 1)
    record([NIT.merge('id' => id)])
    record([NIT.merge('id' => id, 'note' => 'Later decision')], by: { 'name' => name, 'role' => 'task_owner' })
  end
end

class LocalReviewPrivateTriageTest < Minitest::Test
  include SyntheticReviewAssessment

  def test_unknown_legacy_metadata_stays_in_the_ledger_and_out_of_every_comment
    reviewed_finding
    record([NIT.merge('private_context' => 'MUST_REMAIN_LOCAL')])
    record([NIT.merge('note' => 'Public explanation')])
    refute_includes view(EARLIER), 'MUST_REMAIN_LOCAL'
    assert_includes JSON.generate(first_round['earlier_findings']), 'MUST_REMAIN_LOCAL'
  end
end
