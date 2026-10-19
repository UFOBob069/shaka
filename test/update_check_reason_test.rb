# frozen_string_literal: true

require_relative 'update_check_support'

class UpdateCheckReasonTest < Minitest::Test
  include UpdateCheckSupport

  def test_signed_out_cli_names_the_sign_in_command
    error = "To get started with GitHub CLI, please run:  gh auth login\n"
    result = check('ahead', github: ['', error, false])
    assert_equal %w[unknown signed_out], [result.fetch('status'), result.fetch('reason')]
    assert_includes result.fetch('guidance'), 'Run `gh auth login`'
  end

  def test_failed_request_names_its_first_error_line
    offline = "\nerror connecting to api.github.com\ncheck your internet connection\n"
    result = check('ahead', github: ['', offline, false])
    assert_equal 'request_failed', result.fetch('reason')
    assert_includes result.fetch('guidance'), 'The GitHub request failed: error connecting to api.github.com'
    assert_includes result.fetch('guidance'), 'retry'
  end

  def test_malformed_network_answers_are_unknown
    [['not json', '', true], ['{}', '', true], ['[]', '', true]].each do |answer|
      result = check('ahead', github: answer)
      assert_equal %w[unknown invalid_response], [result.fetch('status'), result.fetch('reason')]
    end
  end

  def test_unreadable_checkout_is_unknown_with_its_reason
    runner = ->(argv, _directory) { argv.first == 'git' ? ['', "fatal: not a git repository\n", false] : flunk }
    result = Shaka::UpdateCheck.new(source: SOURCE, branch: 'main', checkout: CHECKOUT, helper: '/installed/shaka',
                                    runner:).result
    assert_equal 'checkout_unreadable', result.fetch('reason')
    assert_includes result.fetch('guidance'), 'fatal: not a git repository. Continue the task'
  end

  def test_unreadable_branch_ancestry_is_not_mistaken_for_a_move
    result = check('identical', head: PULLED, published: ['', "fatal: Not a valid object name\n", false])
    assert_equal 'checkout_unreadable', result.fetch('reason')
    assert_includes result.fetch('guidance'), 'fatal: Not a valid object name'
  end

  def test_option_like_branches_and_dot_dot_segments_are_refused_before_any_command
    ['--upload-pack=x', '../../user', 'a..b'].each do |branch|
      assert_equal 'unsupported_source', check('ahead', branch:).fetch('reason')
      assert_empty @calls
    end
    fork = SOURCE.merge('repository' => 'https://github.com/owner/..')
    assert_equal 'unsupported_source', check('ahead', source: fork).fetch('reason')
    assert_empty @calls
  end

  def test_upstream_rewritten_after_the_last_fetch_is_not_called_local_work
    %w[behind diverged].each do |status|
      result = check(status, head: PULLED)
      assert_equal %w[unknown branch_moved], [result.fetch('status'), result.fetch('reason')]
      assert_includes result.fetch('guidance'), 'official main no longer contains checkout commit bbbbbbb.'
    end
  end

  def test_signed_out_cli_reports_how_to_sign_in
    Dir.mktmpdir('shaka-update-launch') do |directory|
      write_executable(File.join(directory, 'gh'),
                       "#!/bin/sh\necho 'To get started with GitHub CLI, please run:  gh auth login' >&2\nexit 4\n")
      with_path("#{directory}:#{ENV.fetch('PATH')}") do
        result = Dir.chdir(directory) { signed_out_check.result }
        assert_equal %w[unknown signed_out], [result.fetch('status'), result.fetch('reason')]
      end
    end
  end

  def test_local_command_failure_is_not_blamed_on_github
    result = Shaka::UpdateCheck.new(source: SOURCE, branch: 'main', helper: '/installed/shaka',
                                    runner: ->(*) { raise Errno::ENOENT, 'gh' }).result
    assert_equal 'command_failed', result.fetch('reason')
  end

  def test_missing_cli_is_advisory_and_names_the_command
    runner = ->(*) { raise Shaka::UpdateCheck::Launch::Unavailable.new('gh_missing', '`gh` was not found on PATH.') }
    result = Shaka::UpdateCheck.new(source: SOURCE, branch: 'main', helper: '/installed/shaka', runner:).result
    assert_equal %w[unknown gh_missing], [result.fetch('status'), result.fetch('reason')]
    assert_includes result.fetch('guidance'), '`gh` was not found on PATH.'
  end

  private

  def signed_out_check
    source = { 'kind' => 'revision', 'revision' => 'a' * 40, 'repository' => 'https://github.com/shakacode/shaka.git' }
    Shaka::UpdateCheck.new(source:, branch: 'main', helper: '/installed/shaka')
  end

  def with_path(path)
    original = ENV.fetch('PATH')
    ENV['PATH'] = path
    yield
  ensure
    ENV['PATH'] = original
  end

  def write_executable(path, contents)
    File.write(path, contents)
    File.chmod(0o755, path)
  end
end
