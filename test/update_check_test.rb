# frozen_string_literal: true

require_relative 'update_check_support'

class UpdateCheckTest < Minitest::Test
  include UpdateCheckSupport

  def test_newer_official_commits_offer_the_registered_update_without_mutation
    result = check('ahead')
    assert_equal 'available', result.fetch('status')
    assert_includes result.fetch('guidance'), 'install --update'
    assert_includes result.fetch('guidance'), 'Finish active Shaka chats'
    assert_equal [['git', '-C', CHECKOUT, 'rev-parse', '--verify', 'HEAD'], CHECKOUT], @calls.fetch(0)
    assert_equal [['gh', 'api', '--hostname', 'github.com', "repos/shakacode/shaka/compare/#{SHA}...main", '--jq',
                   '{status: .status, ahead_by: .ahead_by, oldest: .commits[0].commit.committer.date}'],
                  Dir.tmpdir], @calls.fetch(1)
  end

  def test_available_update_says_how_many_commits_behind_the_installation_is
    result = check('ahead')
    assert_equal 3, result.fetch('commits_behind')
    assert_includes result.fetch('guidance'), '3 commits behind official main'
    assert_includes check('ahead', ahead_by: 1).fetch('guidance'), '1 commit behind official main'
    assert_includes check('ahead', checkout: nil).fetch('guidance'), '3 commits behind official main'
  end

  def test_available_update_without_a_usable_count_keeps_the_advice_and_omits_the_number
    [nil, 0, -2, '3', 2.5].each do |ahead_by|
      result = check('ahead', ahead_by:)
      assert_equal 'available', result.fetch('status')
      refute result.key?('commits_behind')
      assert_includes result.fetch('guidance'), 'Newer official main commits are available.'
      assert_includes result.fetch('guidance'), 'install --update'
    end
  end

  def test_only_an_available_update_reports_a_count
    %w[identical behind diverged].each { |status| refute check(status).key?('commits_behind') }
  end

  def test_identical_is_current_and_an_ahead_or_diverged_copy_is_not_an_update
    assert_equal 'current', check('identical').fetch('status')
    %w[behind diverged].each do |status|
      assert_equal 'custom', check(status, checkout: nil).fetch('status')
      refute_includes check(status, checkout: nil).fetch('guidance'), 'install --update'
    end
  end

  def test_manual_pull_reports_an_older_record_instead_of_an_update
    guidance = check('identical', head: PULLED).fetch('guidance')
    assert_includes guidance, 'is at bbbbbbb, but its installation record names aaaaaaa. It matches official main'
    assert_includes guidance, '/installed\\ path/scripts/shaka install --update to record it'
    assert_equal ['merge-base', '--is-ancestor', SHA, PULLED], @calls.fetch(1).first.drop(3)
    assert_equal ['merge-base', '--is-ancestor', PULLED, 'refs/remotes/origin/main'], @calls.fetch(2).first.drop(3)
    assert_includes @calls.fetch(3).first, "repos/shakacode/shaka/compare/#{PULLED}...main"
  end

  def test_manual_pull_is_drift_until_newer_commits_make_it_an_update
    assert_equal 'drift', check('identical', head: PULLED).fetch('status')
    assert_equal 'available', check('ahead', head: PULLED).fetch('status')
  end

  # The installer records only a pull, so any other move gets one answer without asking GitHub.
  def test_a_move_the_installer_would_refuse_is_reported_offline
    [{ pulled: ['', '', false] }, { published: ['', '', false] }].each do |answers|
      result = check('ahead', head: PULLED, **answers)
      assert_equal %w[drift not_a_pull], [result.fetch('status'), result.fetch('reason')]
      assert_includes result.fetch('guidance'), '`install --update` will stop'
      refute(@calls.any? { |argv, _| argv.first == 'gh' })
    end
  end

  def test_retained_copy_offers_migration_instead_of_an_unsupported_update
    result = check('ahead', checkout: nil)
    assert_equal 'available', result.fetch('status')
    assert_includes result.fetch('guidance'), 'retained copy'
    refute_includes result.fetch('guidance'), 'install --update'
    assert_equal 1, @calls.size
  end

  def test_fork_compares_against_its_own_registered_branch
    fork = SOURCE.merge('repository' => 'git@github.com:owner/fork.git')
    result = check('ahead', source: fork, branch: 'team/stable', ahead_by: 2)
    assert_equal 'available', result.fetch('status')
    assert_includes result.fetch('guidance'), '2 commits behind owner/fork team/stable'
    assert_includes @calls.fetch(1).first, "repos/owner/fork/compare/#{SHA}...team/stable"
    assert_includes check('identical', branch: 'trial').fetch('guidance'), 'matches shakacode/shaka trial'
  end

  def test_development_and_unsupported_sources_get_manual_advice_without_reads
    { { 'kind' => 'development' } => 'development_source',
      { 'repository' => 'https://gitlab.com/owner/shaka.git' } => 'unsupported_source',
      { 'revision' => 'main' } => 'unsupported_source' }.each do |change, reason|
      result = check('ahead', source: SOURCE.merge(change))
      assert_equal ['custom', reason], [result.fetch('status'), result.fetch('reason')]
      assert_empty @calls
    end
  end

  def test_official_ssh_origins_are_supported
    %w[git@github.com:shakacode/shaka.git git@github.com:shakacode/shaka
       ssh://git@github.com/shakacode/shaka ssh://github.com/shakacode/shaka
       ssh://github.com/shakacode/shaka.git/ https://github.com/ShakaCode/shaka.git
       https://github.com/shakacode/shaka/].each do |origin|
      result = check('ahead', source: SOURCE.merge('repository' => origin), checkout: nil)
      assert_includes result.fetch('guidance'), 'behind official main'
      assert_equal 1, @calls.size
    end
  end

  def test_uninstalled_checkout_does_not_claim_freshness
    assert_equal 'uninstalled', check('ahead', source: { 'kind' => 'uninstalled' }).fetch('status')
    assert_empty @calls
  end
end
