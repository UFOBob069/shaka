# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/update_check'

class UpdateCheckTest < Minitest::Test
  SHA = 'a' * 40
  SOURCE = { 'kind' => 'revision', 'revision' => SHA,
             'repository' => 'https://github.com/shakacode/shaka.git' }.freeze

  def check(status, source: SOURCE, branch: 'main', registered: true, ahead_by: 3)
    @calls = []
    runner = lambda do |argv, directory|
      @calls << [argv, directory]
      [JSON.generate({ 'status' => status, 'ahead_by' => ahead_by, 'oldest' => '2020-01-01T00:00:00Z' }), '', true]
    end
    Shaka::UpdateCheck.new(source:, branch:, registered:, helper: '/installed path/scripts/shaka',
                           runner:).result
  end

  def test_newer_official_commits_offer_the_registered_update_without_mutation
    result = check('ahead')
    assert_equal 'available', result.fetch('status')
    assert_includes result.fetch('guidance'), 'install --update'
    assert_includes result.fetch('guidance'), 'Finish active Shaka chats'
    assert_equal [['gh', 'api', '--hostname', 'github.com', "repos/shakacode/shaka/compare/#{SHA}...main", '--jq',
                   '{status: .status, ahead_by: .ahead_by, oldest: .commits[0].commit.committer.date}'],
                  Dir.tmpdir], @calls.fetch(0)
  end

  def test_available_update_says_how_many_commits_behind_the_installation_is
    result = check('ahead')
    assert_equal 3, result.fetch('commits_behind')
    assert_includes result.fetch('guidance'), '3 commits behind official main'
    assert_includes check('ahead', ahead_by: 1).fetch('guidance'), '1 commit behind official main'
    assert_includes check('ahead', registered: false).fetch('guidance'), '3 commits behind official main'
  end

  def test_available_update_without_a_usable_count_keeps_the_advice_and_omits_the_number
    [nil, 0, -2, '3', 2.5].each do |ahead_by|
      result = check('ahead', ahead_by:)
      assert_equal 'available', result.fetch('status')
      refute result.key?('commits_behind')
      assert_includes result.fetch('guidance'), 'Newer official commits are available.'
      assert_includes result.fetch('guidance'), 'install --update'
    end
  end

  def test_only_an_available_update_reports_a_count
    %w[identical behind diverged].each { |status| refute check(status).key?('commits_behind') }
  end

  def test_identical_is_current_and_an_ahead_or_diverged_trial_is_not_an_update
    assert_equal 'current', check('identical').fetch('status')
    %w[behind diverged].each do |status|
      assert_equal 'custom', check(status).fetch('status')
      refute_includes check(status).fetch('guidance'), 'install --update'
    end
  end

  def test_retained_copy_offers_migration_instead_of_an_unsupported_update
    result = check('ahead', registered: false)
    assert_equal 'available', result.fetch('status')
    assert_includes result.fetch('guidance'), 'retained copy'
    refute_includes result.fetch('guidance'), 'install --update'
  end

  def test_forks_development_and_custom_branches_get_manual_advice_without_network_reads
    [{ 'repository' => 'git@github.com:owner/fork.git' }, { 'kind' => 'development' }].each do |change|
      assert_equal 'custom', check('ahead', source: SOURCE.merge(change)).fetch('status')
      assert_empty @calls
    end
    assert_equal 'custom', check('ahead', branch: 'trial').fetch('status')
    assert_empty @calls
  end

  def test_official_ssh_origins_are_supported
    %w[git@github.com:shakacode/shaka.git git@github.com:shakacode/shaka
       ssh://git@github.com/shakacode/shaka ssh://github.com/shakacode/shaka
       ssh://github.com/shakacode/shaka.git/ https://github.com/ShakaCode/shaka.git
       https://github.com/shakacode/shaka/].each do |origin|
      assert_equal 'available', check('ahead', source: SOURCE.merge('repository' => origin)).fetch('status')
      assert_equal 1, @calls.size
    end
  end

  def test_uninstalled_checkout_does_not_claim_freshness
    assert_equal 'uninstalled', check('ahead', source: { 'kind' => 'uninstalled' }).fetch('status')
    assert_empty @calls
  end

  def test_failed_or_malformed_network_answers_are_unknown
    [['', 'offline', false], ['not json', '', true], ['{}', '', true]].each do |answer|
      result = Shaka::UpdateCheck.new(source: SOURCE, branch: 'main', registered: true,
                                      helper: '/installed/shaka', runner: ->(*) { answer }).result
      assert_equal 'unknown', result.fetch('status')
      assert_includes result.fetch('guidance'), 'retry'
    end
  end

  def test_missing_cli_is_advisory_and_does_not_launch_a_process
    result = Shaka::UpdateCheck.new(source: SOURCE, branch: 'main', registered: true,
                                    helper: '/installed/shaka', runner: ->(*) { raise Errno::ENOENT }).result
    assert_equal 'unknown', result.fetch('status')
  end
end
