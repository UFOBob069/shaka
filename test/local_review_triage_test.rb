# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'local_review_batch_test'

# The reviews of one commit are recorded in one triage, only after every one of them finishes.
class LocalReviewTriageTest < Minitest::Test
  include LocalReviewLedgerSteps

  # Break caught: two reviewers' reports of one problem were triaged twice.
  def test_one_triage_records_every_reviewer_of_a_commit
    append(EARLIER, 'openai/codex', findings: 1)
    append(EARLIER, 'anthropic/claude', findings: 1)

    both = { 'openai/codex' => '1', 'anthropic/claude' => '2' }

    assert_includes assert_raises(Shaka::Error) { record([NIT]) }.message, 'must map each reviewer'
    assert_equal [1, 2], record([NIT.merge('reviewers' => both)])
    assert_equal(%w[1 2], ledger.rounds.map { |round| round['findings'].first['reported_as'] })
  end

  # Break caught: one reviewer finding counted toward two collated findings, hiding another of its findings.
  def test_each_individual_finding_is_collated_once
    append(EARLIER, 'openai/codex', findings: 2)
    append(EARLIER, 'anthropic/claude', findings: 0)
    findings = [NIT.merge('reviewers' => { 'openai/codex' => '1' }),
                NIT.merge('id' => 'F2', 'reviewers' => { 'openai/codex' => '1' })]

    error = assert_raises(Shaka::Error) { record(findings) }
    assert_includes error.message, 'openai/codex finding #1 is collated into two'
  end

  # Break caught: a misspelled or empty reviewer list dropped its finding without an error.
  def test_every_finding_names_reviewers_of_the_batch
    append(EARLIER, 'openai/codex', findings: 1)
    append(EARLIER, 'anthropic/claude', findings: 0)

    unmapped = [{}, ['openai/codex'], { 'openai/codex' => '' }].to_h { |named| [named, 'must map each reviewer'] }
    unmapped.merge({ 'openai/codx' => '1' } => 'names openai/codx').each do |named, message|
      assert_includes assert_raises(Shaka::Error) { record([NIT.merge('reviewers' => named)]) }.message, message
    end
  end

  # Break caught: two problems given one id by different reviewers hid one of them.
  def test_one_id_names_one_problem_across_reviewers
    append(EARLIER, 'openai/codex', findings: 1)
    append(EARLIER, 'anthropic/claude', findings: 1)
    findings = [NIT.merge('reviewers' => { 'openai/codex' => '1' }),
                NIT.merge('reviewers' => { 'anthropic/claude' => '1' })]

    assert_includes assert_raises(Shaka::Error) { record(findings) }.message, 'id repeats'
  end

  # Break caught: a reviewer started after triage, so its findings were triaged apart.
  def test_a_reviewer_cannot_join_a_triaged_commit
    append(EARLIER, 'openai/codex', findings: 0)
    record([])

    error = assert_raises(Shaka::Error) { ledger.check_next!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude') }
    assert_includes error.message, 'already recorded'
  end

  # Break caught: usage that named no reviewer of the batch was dropped without an error.
  def test_usage_must_fit_a_reviewer_of_the_batch
    append(EARLIER, 'openai/codex', findings: 0)
    append(EARLIER, 'anthropic/claude', findings: 0)

    { { tokens: '5' } => 'keyed by reviewer', { usage: { 'openai/codx' => {} } } => 'Usage names openai/codx',
      { usage: { 'openai/codex' => '5' } } => 'map each reviewer',
      { model: 'x', usage: { 'openai/codex' => {} } } => 'keyed by reviewer',
      { usage: nil } => 'map each reviewer' }
      .each do |extra, message|
        assert_includes assert_raises(Shaka::Error) { record([], **extra) }.message, message
      end
  end

  # Break caught: adding usage after triage erased the recorded findings.
  def test_a_usage_only_record_keeps_the_findings
    append(EARLIER, 'openai/codex', findings: 1)
    record([NIT])
    original = ledger.rounds.first['findings']
    ledger.record!({ 'tokens' => '9' })

    assert_equal([original, '9'], ledger.rounds.first.values_at('findings', 'tokens'))
  end

  # Break caught: a second reviewer of a commit used up a turn of the round cap.
  def test_the_round_cap_counts_commits_not_reviewers
    append(EARLIER, 'openai/codex', findings: 0)
    ledger.check_next!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude', max_rounds: 1)
    append(EARLIER, 'anthropic/claude', findings: 0)
    ledger.check_next!(base: BASE, head: HEAD, reviewer: 'openai/codex', max_rounds: 2)

    error = assert_raises(Shaka::LocalReviewLedger::RoundCap) do
      ledger.check_next!(base: BASE, head: HEAD, reviewer: 'openai/codex', max_rounds: 1)
    end
    assert_includes error.message, 'round cap (1)'
  end

  def test_usage_is_recorded_for_each_reviewer
    append(EARLIER, 'openai/codex', findings: 0)
    append(EARLIER, 'anthropic/claude', findings: 0)
    record([], usage: { 'openai/codex' => { 'tokens' => '5,000' } })

    assert_equal(['5,000', nil], ledger.rounds.map { |round| round['tokens'] })
  end
end

# A review marks itself running, so its commit is triaged only after it finishes.
class LocalReviewRunningMarkTest < Minitest::Test
  include LocalReviewLedgerSteps

  # Break caught: a batch was triaged while one of its reviewers was still reading the commit.
  def test_recording_waits_for_every_running_review
    append(EARLIER, 'openai/codex', findings: 0)
    run = ledger
    run.start!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude')

    assert_includes assert_raises(Shaka::Error) { record([]) }.message, 'Wait for anthropic/claude'
    run.finish!
    assert_equal [1], record([])
  end

  # Break caught: recording while the first reviews of a ledger ran said the ledger was empty.
  def test_recording_before_the_first_rounds_names_the_running_reviews
    run = ledger
    run.start!(base: BASE, head: EARLIER, reviewer: 'openai/codex')

    assert_includes assert_raises(Shaka::Error) { record([]) }.message, 'Wait for openai/codex'
    run.finish!
  end

  # Break caught: a record through another spelling of the ledger's directory missed a running review.
  def test_recording_through_a_linked_directory_still_waits
    append(EARLIER, 'openai/codex', findings: 0)
    run = ledger
    run.start!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude')
    linked = File.join(@directory, 'linked')
    File.symlink(@directory, linked)
    other = Shaka::LocalReviewLedger.new(File.join(linked, 'ledger.json'))

    assert_includes assert_raises(Shaka::Error) { other.record!({ 'findings' => [] }) }.message, 'Wait for'
    run.finish!
  end

  # Break caught: a review killed before it cleared its mark blocked the batch forever.
  def test_a_review_whose_process_exited_does_not_block_recording
    append(EARLIER, 'openai/codex', findings: 0)
    start_in_another_process(EARLIER, 'anthropic/claude')

    assert_equal [1], record([])
    refute JSON.parse(File.read(@path)).key?('running')
    assert_empty Dir.glob("#{@path}.running-*")
  end

  # Break caught: a refused second run of one reviewer cleared the live run's mark.
  def test_a_second_run_of_one_reviewer_on_a_commit_is_refused_and_leaves_the_mark
    append(EARLIER, 'openai/codex', findings: 0)
    run = ledger
    run.start!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude')

    error = assert_raises(Shaka::Error) { ledger.start!(base: BASE, head: EARLIER, reviewer: 'Anthropic/Claude') }
    assert_includes error.message, 'already reviewing'
    assert_includes assert_raises(Shaka::Error) { record([]) }.message, 'Wait for anthropic/claude'
    run.finish!
  end

  # Break caught: a new commit's review overtook a reviewer still reading the last commit.
  def test_a_new_commit_waits_for_reviews_of_the_last_one
    append(EARLIER, 'openai/codex', findings: 0)
    run = ledger
    run.start!(base: BASE, head: EARLIER, reviewer: 'anthropic/claude')

    error = assert_raises(Shaka::Error) { ledger.start!(base: BASE, head: HEAD, reviewer: 'openai/codex') }
    assert_includes error.message, 'Wait for anthropic/claude to finish reviewing'
    run.finish!
  end

  # Break caught: a mark naming a file outside the ledger had that file deleted as a stale lock.
  def test_pruning_touches_only_the_ledgers_own_lock_files
    append(EARLIER, 'openai/codex', findings: 0)
    outside = File.join(@directory, 'keep.txt')
    File.write(outside, 'data')
    File.write(@path, JSON.generate(JSON.parse(File.read(@path)).merge(
                                      'running' => [{ 'head' => EARLIER, 'reviewer' => 'x/y', 'lock' => outside }]
                                    )))
    record([])

    assert_path_exists outside
  end

  def test_an_append_clears_its_running_mark
    run = ledger
    run.start!(base: BASE, head: EARLIER, reviewer: 'openai/codex')
    run.append!(base: BASE, round: round_entry(EARLIER, 'openai/codex', 0))

    refute JSON.parse(File.read(@path)).key?('running')
    assert_empty Dir.glob("#{@path}.running-*")
  end

  private

  # Marks a review running from a process that then exits, as a killed review would.
  def start_in_another_process(head, reviewer)
    lib = File.expand_path('../skills/shaka/lib', __dir__)
    script = "require 'shaka/local_review'; Shaka::LocalReviewLedger.new(ARGV[0]).start!(base: ARGV[1], " \
             'head: ARGV[2], reviewer: ARGV[3])'
    assert system(RbConfig.ruby, '-I', lib, '-e', script, @path, BASE, head, reviewer)
  end
end
