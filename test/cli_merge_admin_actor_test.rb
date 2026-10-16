# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'json'

# Runs the merge command against immutable policy with GitHub submission stubbed.
class CliMergeAdminActorTest < Minitest::Test
  include RepositoryConfigTestHelpers

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  HEAD = 'a' * 40
  FAKE_GH = <<~'RUBY_SCRIPT'
    #!/usr/bin/env ruby
    require 'json'
    head = 'a' * 40
    pull = { 'id' => 'PR_123', 'headRefOid' => head, 'baseRefName' => 'main',
             'state' => 'OPEN', 'isDraft' => false, 'viewerCanMergeAsAdmin' => true,
             'isMergeQueueEnabled' => false, 'isInMergeQueue' => false,
             'mergeQueueEntry' => nil, 'autoMergeRequest' => nil,
             'mergeStateStatus' => 'CLEAN', 'reviewDecision' => 'APPROVED',
             'changedFiles' => 1, 'additions' => 1, 'deletions' => 0,
             'commits' => { 'totalCount' => 1 } }
    if ARGV[0, 2] == ['api', 'graphql']
      request = JSON.parse($stdin.read)
      if request.fetch('query').include?('mergePullRequest')
        File.write(ENV.fetch('MUTATION_FILE'), JSON.generate(request))
        result = { 'mergePullRequest' => { 'pullRequest' => pull.merge('state' => 'MERGED', 'merged' => true) } }
      else
        result = { 'repository' => { 'pullRequest' => pull } }
      end
      puts JSON.generate('data' => result)
    elsif ARGV[0, 2] == ['pr', 'checks'] && ENV['NO_REQUIRED_CHECKS'] && ARGV.include?('--required')
      warn "no required checks reported on the 'main' branch"
      exit 1
    elsif ARGV[0] == 'api' && ARGV[1].start_with?('repos/owner/repo/rules/branches/main')
      puts '[]'
    elsif ARGV[0, 2] == ['pr', 'checks']
      puts JSON.generate([{ 'name' => 'checks', 'state' => 'SUCCESS', 'bucket' => 'pass' }])
    elsif ARGV[0, 2] == ['api', 'repos/owner/repo/pulls/1/reviews/17']
      puts JSON.generate('id' => 17, 'commit_id' => head, 'state' => 'COMMENTED', 'body' => 'Walkthrough')
    elsif ARGV[0] == 'api' && ARGV[1].start_with?('repos/owner/repo/pulls/1/commits?')
      puts JSON.generate([{ 'sha' => head, 'commit' => { 'message' => 'Fix' } }])
    else
      warn "unexpected gh #{ARGV.join(' ')}"
      exit 2
    end
  RUBY_SCRIPT

  def test_admin_actor_can_merge_without_account_configuration
    with_merge_repository do |root, ref, mutation|
      output, error, status = run_merge(root, ref, mutation)

      assert_predicate status, :success?, error
      assert_equal 'MERGED', JSON.parse(output)['state']
      assert_path_exists mutation
      assert_equal 'Reason.', JSON.parse(File.read(mutation)).dig('variables', 'body')
    end
  end

  def test_unprotected_branch_refuses_an_unconfirmed_merge
    with_merge_repository do |root, ref, mutation|
      _, error, status = run_merge(root, ref, mutation, env: { 'NO_REQUIRED_CHECKS' => '1' })

      refute_predicate status, :success?
      assert_match(/--empty-checks-confirmed-head/, error)
      refute_path_exists mutation
    end
  end

  def test_unprotected_branch_merges_the_head_the_user_confirmed
    with_merge_repository do |root, ref, mutation|
      output, error, status = run_merge(root, ref, mutation, '--empty-checks-confirmed-head', HEAD,
                                        env: { 'NO_REQUIRED_CHECKS' => '1' })

      assert_predicate status, :success?, error
      assert_equal HEAD, JSON.parse(output)['empty_required_checks_confirmed_head']
      assert_path_exists mutation
    end
  end

  private

  def with_merge_repository
    with_repository('merge' => merge_policy,
                    'review' => review_policy('required' => 'none', 'post_implementation' => { 'enabled' => false })
                                .except('ci_review_jobs')) do |root|
      commit_repository(root)
      ref, = Open3.capture3('git', '-C', root, 'rev-parse', 'HEAD')
      ref = ref.strip
      install_fake_github(root)
      File.write(File.join(root, 'message.json'), JSON.generate('title' => 'Fix', 'body' => 'Reason.'))
      yield root, ref, File.join(root, 'mutation.json')
    end
  end

  def commit_repository(root)
    [%w[init --quiet], %w[add .],
     %w[-c user.name=Test -c user.email=test@example.com commit --quiet -m trusted]].each do |args|
      system('git', '-C', root, *args, exception: true)
    end
  end

  def install_fake_github(root)
    bin = File.join(root, 'fake-bin')
    FileUtils.mkdir_p(bin)
    File.write(fake = File.join(bin, 'gh'), FAKE_GH)
    File.chmod(0o755, fake)
  end

  def run_merge(root, ref, mutation, *extra, env: {})
    Open3.capture3({ 'PATH' => "#{root}/fake-bin:#{ENV.fetch('PATH')}", 'MUTATION_FILE' => mutation }.merge(env),
                   COMMAND, 'merge', 'owner/repo', '1', '--root', root, '--ref', ref,
                   '--head', HEAD, '--base', 'main', '--walkthrough', '17',
                   '--squash-message', File.join(root, 'message.json'), *extra)
  end
end
