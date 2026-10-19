# frozen_string_literal: true

require_relative 'github_helper'

class GitHubUnprotectedCheckListTest < Minitest::Test
  include GitHubHelper

  def test_required_checks_treat_the_unprotected_diagnostic_as_an_empty_list
    message = "no required checks reported on the 'main' branch\n"
    assert_empty client(['', message, STATUS.new(1)]).required_checks
  end

  def test_required_checks_treat_a_repo_with_no_checks_as_an_empty_list
    message = "no checks reported on the 'main' branch\n"
    assert_empty client(['', message, STATUS.new(1)]).required_checks
  end

  def test_checks_treat_the_no_checks_diagnostic_as_an_empty_list
    message = "no checks reported on the 'main' branch\n"
    assert_empty client(['', message, STATUS.new(1)]).checks
  end

  def test_checks_do_not_treat_the_required_diagnostic_as_an_empty_list
    message = "no required checks reported on the 'main' branch\n"
    error = assert_raises(Shaka::Error) { client(['', message, STATUS.new(1)]).checks }
    assert_equal 'gh pr 42 failed (exit 1).', error.message
  end

  def test_checks_keep_the_gh_error_when_rate_limited
    stderr = "gh: API rate limit exceeded (HTTP 403)\n"
    error = assert_raises(Shaka::Error) { client(['', stderr, STATUS.new(1)]).checks }
    assert_equal 'gh pr 42 failed (exit 1).', error.message
    assert_equal 403, error.http_status
  end

  def test_required_checks_keep_the_status_when_rate_limited
    stderr = "gh: API rate limit exceeded (HTTP 403)\n"
    error = assert_raises(Shaka::Error) { client(['', stderr, STATUS.new(1)]).required_checks }
    assert_match(/Required-check evidence is unavailable/, error.message)
    assert_equal 403, error.http_status
  end

  def test_checks_still_read_failing_checks_from_exit_one
    failing = [{ 'name' => 'test', 'state' => 'FAILURE', 'bucket' => 'fail' }]
    assert_equal failing, client([JSON.generate(failing), '', STATUS.new(1)]).checks
  end

  def test_required_checks_keep_a_truncated_diagnostic_as_unavailable
    error = assert_raises(Shaka::Error) do
      client(['', 'no required checks reported', STATUS.new(1)]).required_checks
    end
    assert_match(/Required-check evidence is unavailable/, error.message)
  end

  def test_required_checks_keep_extra_stderr_as_unavailable
    stderr = "no required checks reported on the 'main' branch\nHTTP 503 while querying checks\n"
    error = assert_raises(Shaka::Error) do
      client(['', stderr, STATUS.new(1)]).required_checks
    end
    assert_match(/Required-check evidence is unavailable/, error.message)
  end

  def test_required_checks_keep_malformed_json_as_unavailable
    error = assert_raises(Shaka::Error) do
      client(['broken JSON', 'private stderr', STATUS.new(0)]).required_checks
    end
    assert_match(/Required-check evidence is unavailable/, error.message)
  end
end
