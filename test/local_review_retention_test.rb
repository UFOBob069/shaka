# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'local_review_batch_test'
require 'digest'
require 'json'

# Appends one clean round and reads back what the ledger stored.
module LocalReviewRetentionSteps
  include LocalReviewLedgerSteps

  private

  def append_round
    entry = round_entry(EARLIER, 'openai/codex', 0)
    original = File.read(entry.fetch('report'))
    ledger.append!(base: BASE, round: entry)
    original
  end

  def stored = JSON.parse(File.read(@path))

  def kept_round = stored.fetch('rounds').first
end

# A ledger keeps its own copy of each report, so the review survives the reviewer's temporary files.
class LocalReviewRetentionTest < Minitest::Test
  include LocalReviewRetentionSteps

  def test_a_round_keeps_a_copy_of_its_report_beside_the_ledger
    original = append_round
    digest = Digest::SHA256.hexdigest(original)
    copy = File.join(File.dirname(ledger.path), 'reports', "#{digest}.md")

    assert_equal({ 'report' => copy, 'report_sha256' => digest }, kept_round.slice('report', 'report_sha256'))
    assert_equal original, File.read(copy)
    assert_equal 2, stored.fetch('version')
  end

  def test_the_review_publishes_after_the_reviewers_own_report_file_is_gone
    append_round
    FileUtils.rm_f(@reports)

    body = Shaka::LocalReviewComment.render(Shaka::LocalReviewBundle.resolve(stored, @directory))
    assert_includes body, "REVIEWED #{EARLIER} BY openai/codex"
    assert_equal [1], ledger.record!({ 'findings' => [] })
  end

  def test_a_ledger_moved_to_another_directory_still_reads_its_reports
    append_round
    content = stored
    moved = "#{@directory}-moved"
    FileUtils.mv(@directory, moved)

    report = Shaka::LocalReviewBundle.resolve(content, moved).fetch('rounds').first.fetch('report')
    assert_equal File.join(moved, 'reports'), File.dirname(report)
  ensure
    FileUtils.rm_rf(moved)
  end

  # Break caught: only publishing found a moved copy, so recording after a move read the old path.
  def test_a_moved_ledger_still_records_and_continues_the_loop
    append(EARLIER, 'openai/codex', findings: 1)
    FileUtils.mv(@directory, moved = "#{@directory}-moved")
    FileUtils.rm_f(@reports)
    @path = File.join(moved, 'ledger.json')

    assert_equal [1], record([NIT])
    ledger.check_next!(base: BASE, head: HEAD, reviewer: 'openai/codex')
    assert_equal File.join(File.realpath(moved), 'reports'), File.dirname(kept_round.fetch('report'))
  ensure
    FileUtils.rm_rf(moved)
  end

  def test_a_matching_copy_beside_the_ledger_wins_over_a_changed_recorded_file
    append_round
    content = stored
    copied = "#{@directory}-copied"
    FileUtils.cp_r(@directory, copied)
    File.write(kept_round.fetch('report'), 'edited')

    report = Shaka::LocalReviewBundle.resolve(content, copied).fetch('rounds').first.fetch('report')
    assert_equal File.join(copied, 'reports'), File.dirname(report)
  ensure
    FileUtils.rm_rf(copied)
  end

  def test_a_report_that_cannot_be_copied_appends_no_round
    entry = round_entry(EARLIER, 'openai/codex', 0)
    FileUtils.rm_f(entry.fetch('report'))

    error = assert_raises(Shaka::Error) { ledger.append!(base: BASE, round: entry) }
    assert_includes error.message, 'could not be kept'
    refute_path_exists @path
  end
end

# A report that is gone or changed is named, and ledgers from other versions keep their meaning.
class LocalReviewUnavailableReportTest < Minitest::Test
  include LocalReviewRetentionSteps

  def test_a_missing_bundled_report_is_named_as_unavailable
    append_round
    FileUtils.rm_f(Dir.glob(File.join(@directory, 'reports', '*')))

    error = assert_raises(Shaka::Error) { Shaka::LocalReviewBundle.resolve(stored, @directory) }
    assert_includes error.message, "Round 1's report is unavailable"
    assert_includes error.message, 'missing'
  end

  def test_an_altered_bundled_report_is_named_as_unavailable
    append_round
    copy = Dir.glob(File.join(@directory, 'reports', '*')).first
    File.write(copy, "edited\nREVIEWED #{EARLIER} BY openai/codex EFFORT UNKNOWN FINDINGS 0\n")

    error = assert_raises(Shaka::Error) { Shaka::LocalReviewBundle.resolve(stored, @directory) }
    assert_includes error.message, "Round 1's report is unavailable"
    assert_includes error.message, 'changed'
  end

  def test_publishing_stops_before_github_and_names_the_unavailable_report
    append_round
    FileUtils.rm_f(Dir.glob(File.join(@directory, 'reports', '*')))

    _output, error = capture_io do
      assert_equal 1,
                   Shaka::LocalReview.run(['publish', 'owner/repo', '1', '--content-file', @path], github: Object.new)
    end
    assert_includes error, "Round 1's report is unavailable"
  end

  def test_an_earlier_ledger_without_copies_still_reads_its_reports
    path = report(EARLIER, findings: 0)
    File.write(@path, JSON.generate('base' => BASE, 'rounds' => [{ 'head' => EARLIER, 'reviewer' => 'openai/codex',
                                                                   'report' => path }]))

    resolved = Shaka::LocalReviewBundle.resolve(stored, @directory)
    assert_equal path, resolved.fetch('rounds').first.fetch('report')
    ledger.check_next!(base: BASE, head: HEAD, reviewer: 'openai/codex')
  end

  def test_an_earlier_ledger_whose_report_is_gone_is_named_as_unavailable
    File.write(@path, JSON.generate('rounds' => [{ 'head' => EARLIER, 'reviewer' => 'openai/codex',
                                                   'report' => File.join(@directory, 'gone.md') }]))

    error = assert_raises(Shaka::Error) { Shaka::LocalReviewBundle.resolve(stored, @directory) }
    assert_includes error.message, "Round 1's report is unavailable"
  end

  def test_a_ledger_from_a_newer_shaka_is_refused
    File.write(@path, JSON.generate('version' => 3, 'rounds' => []))

    error = assert_raises(Shaka::Error) { ledger.rounds }
    assert_includes error.message, 'newer Shaka'
  end

  def test_only_a_ledger_in_a_temporary_directory_carries_the_warning
    assert_includes Shaka::LocalReviewBundle.warning(@path), 'temporary directory'
    assert_includes Shaka::LocalReviewBundle.warning('/tmp/shaka-review/ledger.json'), 'temporary directory'
    assert_nil Shaka::LocalReviewBundle.warning(File.join(Dir.home, '.local/state/shaka/reviews/task/ledger.json'))
  end
end
