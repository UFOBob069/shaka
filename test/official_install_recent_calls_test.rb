# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'official_install_support'

class OfficialInstallRecentCallsTest < Minitest::Test
  include OfficialInstallSupport

  def setup
    super
    @installed = File.join(@directory, 'installation')
    @log = File.join(@directory, 'calls.jsonl')
    official_install_at(@installed)
    File.write(File.join(@source, 'SKILL.md'), 'updated skill')
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
  end

  def test_update_stops_before_fetching_when_a_call_ended_recently
    started = Time.at(Time.now.to_i - 1200).utc
    log_call('review run', at: started, duration_ms: 600_000)
    before = git('-C', @installed, 'rev-parse', 'origin/main')
    output, status = update
    refute_predicate status, :success?
    assert_includes output, 'Shaka was used in the last 15 minutes'
    assert_includes output, "review run ended at #{(started + 600).iso8601} in #{@log}"
    assert_includes output, 'install --update --force'
    assert_not_fetched(before)
  end

  def test_force_updates_despite_a_recent_call
    log_call('pr', at: Time.now.utc - 60)
    assert_updated(*update('--force'))
  end

  def test_update_proceeds_when_calls_are_old_or_do_not_show_an_open_chat
    log_call('workflow', at: Time.now.utc - 3600, duration_ms: 1000)
    log_call('install', at: Time.now.utc - 30)
    log_call('update-check', at: Time.now.utc - 20)
    File.write(@log, "not json\n{\"at\":1,\"command\":\"pr\"}\n", mode: 'a')
    assert_updated(*update)
  end

  def test_a_call_with_a_malformed_duration_still_stops_the_update
    log_call('pr', at: Time.now.utc - 60, duration_ms: {})
    output, status = update
    refute_predicate status, :success?
    assert_includes output, 'Shaka was used in the last 15 minutes'
  end

  def test_force_requires_update
    output, status = invoke('--verify', '--force')
    refute_predicate status, :success?
    assert_includes output, 'Use --force only with --update'
  end

  private

  def assert_updated(output, status)
    assert_predicate status, :success?, output
    assert_equal 'updated skill', File.read(File.join(@destination, 'SKILL.md'))
  end

  def assert_not_fetched(before)
    assert_equal before, git('-C', @installed, 'rev-parse', 'origin/main')
    refute_equal 'updated skill', File.read(File.join(@destination, 'SKILL.md'))
  end

  def official_install_at(directory)
    output, status = invoke('--directory', directory, '--repository', @remote, '--skills-dir', @skills_dir)
    assert_predicate status, :success?, output
  end

  def log_call(command, at:, duration_ms: 5)
    record = { 'at' => at.iso8601, 'command' => command, 'exit' => 0, 'duration_ms' => duration_ms }
    File.write(@log, "#{JSON.generate(record)}\n", mode: 'a')
  end

  def update(*)
    Open3.capture2e({ 'HOME' => @home, 'SHAKA_CALL_LOG' => @log }, RbConfig.ruby, @installer,
                    '--directory', @installed, '--update', *)
  end
end
