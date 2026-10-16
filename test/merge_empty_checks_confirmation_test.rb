# frozen_string_literal: true

require_relative 'merge_test'

# A user's confirmation of one head excuses only an empty required-check set; every other gate stays.
class MergeEmptyChecksConfirmationTest < Minitest::Test
  include MergeFixtures

  def test_merges_the_head_the_user_confirmed
    @client.checks = []

    result = merge_with(HEAD)

    assert_equal 'MERGED', result.fetch('state')
    assert_equal HEAD, result.fetch('empty_required_checks_confirmed_head')
  end

  def test_refuses_a_confirmation_of_another_head
    @client.checks = []

    assert_refused(/names c{40}, not the current head/, 'c' * 40)
  end

  def test_refusal_without_confirmation_names_the_flag
    @client.checks = []

    assert_refused(/--empty-checks-confirmed-head/, nil)
  end

  def test_does_not_excuse_unknown_failing_or_pending_checks
    [nil, {}, [{ 'name' => 'Validate', 'state' => 'FAILURE', 'bucket' => 'fail' }],
     [{ 'name' => 'Validate', 'state' => 'PENDING', 'bucket' => 'pending' }]].each do |checks|
      @client.checks = checks

      assert_refused(/No observable required checks|not passing/, HEAD)
    end
  end

  def test_passing_checks_report_no_excused_set
    result = merge_with(HEAD)

    assert_equal 'MERGED', result.fetch('state')
    refute result.key?('empty_required_checks_confirmed_head')
  end

  def test_keeps_the_native_review_gate
    @client.checks = []
    @client.snapshots = [snapshot.merge('reviewDecision' => 'REVIEW_REQUIRED')]

    assert_refused(/Required reviews/, HEAD)
  end

  private

  def merge_with(confirmed)
    @merge.empty_checks_confirmed_head = confirmed
    @merge.call(head: HEAD, base: BASE, walkthrough: 17)
  end

  def assert_refused(pattern, confirmed)
    error = assert_raises(Shaka::Error) { merge_with(confirmed) }
    assert_match pattern, error.message
    assert_empty @client.mutations
  end
end
