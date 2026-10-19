# frozen_string_literal: true

require_relative 'startup_notice_support'

class StartupNoticeTest < Minitest::Test
  include StartupNoticeSupport

  def test_stale_or_missing_answer_asks_for_a_check_once_per_day
    assert_match(/not checked for updates in the last day\. Run .*installed.* update-check\./, notice)
    assert_nil notice(now: NOW + 3600)
    assert_match(/not checked/, notice(now: NOW + Shaka::UpdateCheck::Cache::SECONDS + 1))
  end

  def test_repeats_an_actionable_cached_answer_once_per_day
    %w[available drift].each do |status|
      remember(status, at: NOW)
      assert_equal "shaka: #{status} guidance", notice(now: NOW + 60)
      assert_nil notice(now: NOW + 120)
      FileUtils.rm_f(Shaka::UpdateCheck::Cache.path(@home))
    end
  end

  def test_a_new_answer_keeps_the_day_limit
    remember('available', at: NOW)
    notice(now: NOW + 60)
    remember('drift', at: NOW + 120)
    assert_nil notice(now: NOW + 180)
  end

  def test_a_notice_that_cannot_be_recorded_is_not_shown
    directory = File.dirname(Shaka::UpdateCheck::Cache.path(@home))
    FileUtils.mkdir_p(directory)
    File.chmod(0o500, directory)
    assert_nil notice
  ensure
    File.chmod(0o700, directory)
  end

  def test_settled_answers_stay_quiet
    %w[current recent custom unknown].each do |status|
      remember(status, at: NOW)
      assert_nil notice(now: NOW + 60), status
    end
  end

  def test_another_checkouts_answer_counts_as_missing
    other = checkout('other', registered: true)
    Shaka::UpdateCheck::Cache.record(other, answer('available'), home: @home, now: NOW)
    assert_match(/not checked/, notice)
  end

  def test_skipped_commands_and_the_off_switch_print_nothing
    [[['update-check'], {}], [%w[install --update], {}], [[], {}], [['pr'], { 'SHAKA_NOTICES' => 'off' }]]
      .each do |arguments, env|
        output = StringIO.new
        Shaka::StartupNotice.call(arguments, env:, output:)
        assert_empty output.string, arguments.inspect
      end
  end

  def test_update_check_caches_only_a_registered_checkout
    cache = Shaka::UpdateCheck::Cache.path(@home)
    with_home { Shaka::UpdateCheck.new(source: {}, branch: 'main', helper: 'h').remember(answer('current')) }
    refute_path_exists cache
    with_home { Shaka::UpdateCheck.new(source: {}, branch: 'main', helper: 'h', checkout: @root).remember(answer('drift')) }
    assert_equal 'drift', JSON.parse(File.read(cache)).dig('result', 'status')
  end

  def test_a_failed_check_is_not_saved_so_the_reminder_continues
    check = Shaka::UpdateCheck.new(source: {}, branch: 'main', helper: 'h', checkout: @root)
    with_home { check.remember(answer('unknown')) }
    refute_path_exists Shaka::UpdateCheck::Cache.path(@home)
    assert_match(/not checked/, notice)
  end

  def test_a_checkout_reached_through_a_link_shares_its_entry
    linked = File.join(@directory, 'linked checkout')
    File.symlink(@root, linked)
    Shaka::UpdateCheck::Cache.record(linked, answer('available'), home: @home, now: NOW)
    assert_equal 'shaka: available guidance', notice(now: NOW + 60)
  end

  # update-check writes under the root the notice reads, so its answers are this helper's own.
  def test_update_check_and_the_notice_name_the_same_checkout
    assert_equal Shaka::UpdateCheck::ROOT, Shaka::StartupNotice::ROOT
  end

  # A new chat hears the saved answer every time it starts, so this path has no daily limit.
  def test_session_start_reports_the_saved_answer_as_plain_text
    remember('drift', at: NOW)
    2.times { assert_equal "Shaka update check: drift guidance\n", session_start(now: NOW + 60) }
    remember('current', at: NOW)
    assert_empty session_start(now: NOW + 60)
    assert_match(/\AShaka update check: Shaka has not checked/, session_start(now: NOW + (2 * 24 * 3600)))
    assert_empty session_start(now: NOW, root: checkout('development', registered: false))
  end

  def test_cached_notice_and_session_start_run_no_command
    remember('available', at: Time.now)
    script = 'warn "shaka: " + Shaka::StartupNotice.new(home: Dir.home, root: ARGV[0]).line; ' \
             'Shaka::StartupNotice.session_start(root: ARGV[0])'
    output, error, status = Open3.capture3({ 'HOME' => @home, 'PATH' => fake_commands }, RbConfig.ruby, '-I',
                                           LIBRARY, '-rshaka/startup_notice', '-e', script, @root)
    assert_predicate status, :success?, error
    assert_equal ["shaka: available guidance\n", "Shaka update check: available guidance\n"], [error, output]
    refute_path_exists ran
  end

  private

  def session_start(now:, root: @root)
    output = StringIO.new
    Shaka::StartupNotice.session_start(output:, home: @home, root:, now:)
    output.string
  end

  def with_home
    previous = Dir.home
    ENV['HOME'] = @home
    yield
  ensure
    ENV['HOME'] = previous
  end
end
