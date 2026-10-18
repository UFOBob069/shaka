# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/harbor_trial'
require_relative 'support/evaluation_budget_fixture'
require_relative 'support/evaluation_harbor_fixture'

class EvaluationHarborTrialTest < Minitest::Test
  include EvaluationBudgetFixture
  include EvaluationHarborFixture

  def test_subprocess_collects_all_sessions_and_charges_actual_usage
    setup_harbor
    account = budget
    result = harbor_run(account)
    assert_equal 'complete', result['status']
    assert_equal '1.0', account.snapshot['monthly_dollars']
    saved = saved_harbor_record
    assert_equal @usage.rate_card_hash, saved.dig('fingerprint', 'rate_card_hash')
    assert_equal 1, saved.dig('usage', 'cache_neutral_dollars')
  end

  def test_native_exception_is_charged_even_with_zero_process_exit_and_no_retry
    setup_harbor(mode: 'exception')
    account = budget
    result = harbor_run(account, count: 2)
    assert_equal 'harness_error', result['status']
    assert_equal '1.0', account.snapshot['monthly_dollars']
    saved = saved_harbor_record
    assert_equal 'HARNESS_ERROR', saved.dig('outcome', 'state')
    assert_equal 'UNKNOWN', saved['score']
    refute_includes JSON.generate(saved), 'private-native-error'
  end

  def test_timeout_retains_cost_and_cleans_only_owned_resources
    setup_harbor(mode: 'timeout', timeout: 1)
    result = harbor_run
    assert_equal 'harness_error', result['status']
    assert_equal '1.0', result['dollars']
    remaining = JSON.parse(File.read(File.join(@directory, 'resources.json')))
    assert_equal(%w[container2 network2 volume2], remaining.map { |entry| entry.fetch('Id') })
    assert_empty Dir.glob(File.join(@directory, 'captures/controller-*'))
    assert_child_stopped
  end

  def test_nonzero_exit_is_charged_and_stops
    setup_harbor(mode: 'exit')
    result = harbor_run
    assert_equal 'harness_error', result['status']
    assert_equal '1.0', result['dollars']
  end

  def test_missing_result_is_a_charged_harness_failure
    setup_harbor(mode: 'missing-result')
    result = harbor_run
    assert_equal 'harness_error', result['status']
    assert_equal '1.0', result['dollars']
  end

  def test_collection_rejects_a_session_resolving_outside_its_trial
    setup_harbor(mode: 'foreign-session')
    account = budget
    result = harbor_run(account)
    assert_equal 'harness_error', result['status']
    assert_equal 1, account.snapshot['pending']
  end

  def test_cleanup_failure_tries_remaining_resources_and_blocks_the_account
    setup_harbor(mode: 'cleanup-error')
    account = budget
    assert_equal 'harness_error', harbor_run(account)['status']
    assert_equal 1, account.snapshot['pending']
    assert_equal %w[container0 container1 container2 network2 volume2], remaining_resource_ids
    assert_empty Dir.glob(File.join(@directory, 'captures/controller-*'))
  end

  def test_collection_rejects_a_session_directory_resolving_outside_its_trial
    setup_harbor(mode: 'foreign-session-root')
    account = budget
    assert_equal 'harness_error', harbor_run(account)['status']
    assert_equal 1, account.snapshot['pending']
  end

  def test_capture_keeps_only_image_identity_from_docker_inspection
    setup_harbor
    harbor_run
    assert_equal 2, @capture.fetch('images').size
    assert_equal %w[image_digest project], @capture.fetch('images').first.keys
  end

  def test_unknown_usage_blocks_later_launches
    setup_harbor
    @usage.define_singleton_method(:read) do |**|
      { 'models' => [], 'cache_neutral_dollars' => 'UNKNOWN', 'billed_dollars' => 'UNKNOWN' }
    end
    account = budget
    assert_equal 'harness_error', harbor_run(account)['status']
    assert_equal 1, account.snapshot['pending']
    FileUtils.rm(File.join(@directory, 'observed.json'))
    assert_equal 'unaccounted_trial', harbor_run(account)['reason']
    refute_path_exists File.join(@directory, 'observed.json')
  end

  private

  def remaining_resource_ids
    JSON.parse(File.read(File.join(@directory, 'resources.json'))).map { |entry| entry.fetch('Id') }
  end

  def assert_child_stopped
    pid = File.read(File.join(@directory, 'child-pid')).strip
    state, = Open3.capture2('ps', '-p', pid, '-o', 'stat=')
    assert(state.strip.empty? || state.strip.start_with?('Z'), "Native descendant still active: #{state}")
  end
end
