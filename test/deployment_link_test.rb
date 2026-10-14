# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/deployment_link'

# Resolves previews from deployment records or authenticated current-head checks.
module DeploymentLinkFixtures
  HEAD = 'a' * 40

  # Answers the deployment reads for one pull request head.
  class RecordedGitHub
    attr_reader :repository, :reads

    def initialize(deployments, statuses, checks: [])
      @repository = 'owner/repo'
      @deployments = deployments
      @statuses = statuses
      @checks = checks
      @reads = []
    end

    def snapshot = { 'headRefOid' => HEAD }

    def api(path)
      @reads << path
      expected = "repos/owner/repo/commits/#{HEAD}/check-runs?check_name=Cloudflare%20Pages&app_id=85455&per_page=100"
      unless path == expected
        raise Shaka::Error,
              "Unexpected read: #{path}"
      end

      { 'total_count' => @checks.size, 'check_runs' => @checks }
    end

    def api_list(path)
      @reads << path
      return @deployments if path == "repos/owner/repo/deployments?sha=#{HEAD}&per_page=100"

      id = path[%r{\Arepos/owner/repo/deployments/(\d+)/statuses\?per_page=1\z}, 1]
      raise Shaka::Error, "Unexpected read: #{path}" unless id

      Array(@statuses.fetch(id.to_i))
    end
  end

  def status(state, url = nil) = { 'state' => state, 'environment_url' => url }

  def resolve(deployments, statuses, checks: [], deployment: 'auto')
    Shaka::DeploymentLink.resolve({ 'deployment' => deployment }, RecordedGitHub.new(deployments, statuses, checks:))
  end

  def cloudflare_check(id: 1, head: HEAD, conclusion: 'success', app_id: 85_455)
    { 'id' => id, 'name' => 'Cloudflare Pages', 'head_sha' => head, 'status' => 'completed',
      'conclusion' => conclusion, 'app' => { 'id' => app_id, 'slug' => 'cloudflare-workers-and-pages' },
      'output' => { 'summary' => +'<table><tr><td><strong>Preview URL:</strong></td>' \
                                  "<td><a href='https://72086ad2.example.pages.dev'>Preview</a></td></tr>" \
                                  '<tr><td><strong>Branch Preview URL:</strong></td>' \
                                  "<td><a href='https://branch.example.pages.dev'>Branch</a></td></tr></table>" } }
  end
end

class CloudflarePreviewTest < Minitest::Test
  include DeploymentLinkFixtures

  def test_auto_finds_the_immutable_cloudflare_preview_when_the_deployments_api_is_empty
    assert_equal 'https://72086ad2.example.pages.dev', resolve([], {}, checks: [cloudflare_check])['deployment']
  end

  def test_a_check_name_alone_or_a_stale_commit_cannot_supply_the_preview
    [cloudflare_check(app_id: 123), cloudflare_check(head: 'b' * 40),
     cloudflare_check.merge('app' => { 'id' => 85_455, 'slug' => 'other' })].each do |check|
      assert_equal 'none', resolve([], {}, checks: [check])['deployment']
    end
  end

  def test_failed_pending_and_url_less_checks_do_not_supply_a_preview
    [cloudflare_check(conclusion: 'failure'), cloudflare_check.merge('status' => 'in_progress'),
     cloudflare_check.merge('output' => { 'summary' => '' })].each do |check|
      assert_equal 'none', resolve([], {}, checks: [check])['deployment']
    end
  end

  def test_the_latest_cloudflare_run_supersedes_an_older_success
    checks = [cloudflare_check(id: 2, conclusion: 'failure'), cloudflare_check]
    assert_equal 'none', resolve([], {}, checks:)['deployment']
  end

  def test_unrelated_branch_and_unsafe_urls_are_not_published
    ['http://72086ad2.example.pages.dev', 'https://preview.example.com',
     'https://user:secret@example.pages.dev', 'https://example.pages.dev.evil.test'].each do |url|
      check = cloudflare_check
      check['output']['summary'].sub!('https://72086ad2.example.pages.dev', url)
      assert_equal 'none', resolve([], {}, checks: [check])['deployment']
    end
    check = cloudflare_check
    check['output']['summary'].sub!('Preview URL:', 'Other URL:')
    assert_equal 'none', resolve([], {}, checks: [check])['deployment']
  end

  def test_double_quoted_multiline_html_resolves_the_immutable_preview
    check = cloudflare_check
    check['output']['summary'].tr!("'", '"')
    check['output']['summary'].gsub!('><', ">\n<")
    assert_equal 'https://72086ad2.example.pages.dev', resolve([], {}, checks: [check])['deployment']
  end

  def test_truncated_check_results_do_not_prove_there_is_no_preview
    github = RecordedGitHub.new([], {})
    def github.api(_path) = { 'total_count' => 101, 'check_runs' => [] }
    error = assert_raises(Shaka::Error) { Shaka::DeploymentLink.resolve({ 'deployment' => 'auto' }, github) }
    assert_includes error.message, 'Too many check runs'
  end

  def test_github_deployments_win_without_reading_cloudflare_checks
    github = RecordedGitHub.new([{ 'id' => 1 }], { 1 => [status('success', 'https://deployed.example')] },
                                checks: [cloudflare_check])
    assert_equal 'https://deployed.example',
                 Shaka::DeploymentLink.resolve({ 'deployment' => 'auto' }, github)['deployment']
    assert_equal 2, github.reads.size
  end

  def test_a_different_check_name_is_ignored_even_from_the_cloudflare_app
    assert_equal 'none', resolve([], {}, checks: [cloudflare_check.merge('name' => 'Cloudflare Workers')])['deployment']
  end

  def test_missing_check_permissions_are_reported_rather_than_hidden_as_no_preview
    github = RecordedGitHub.new([], {})
    def github.api(_path) = raise(Shaka::Error, 'Checks access denied')
    error = assert_raises(Shaka::Error) { Shaka::DeploymentLink.resolve({ 'deployment' => 'auto' }, github) }
    assert_equal 'Checks access denied', error.message
  end

  def test_captured_cloudflare_pages_output_from_the_reported_pr
    summary = File.read(File.join(__dir__, 'fixtures/cloudflare_pages_preview.html'))
    check = cloudflare_check.merge('output' => { 'summary' => summary })
    assert_equal 'https://72086ad2.sc-website-bv4.pages.dev', resolve([], {}, checks: [check])['deployment']
  end
end

class DeploymentLinkTest < Minitest::Test
  include DeploymentLinkFixtures

  def test_auto_uses_the_newest_successful_deployment_url_for_the_head
    deployments = [{ 'id' => 2, 'created_at' => '2026-09-24T02:00:00Z' },
                   { 'id' => 1, 'created_at' => '2026-09-24T01:00:00Z' }]
    statuses = { 2 => [status('success', 'https://new.example')], 1 => [status('success', 'https://old.example')] }

    assert_equal({ 'deployment' => 'https://new.example' }, resolve(deployments, statuses))
  end

  def test_auto_skips_failed_inactive_and_url_less_deployments
    deployments = [{ 'id' => 4, 'created_at' => '2026-09-24T04:00:00Z' },
                   { 'id' => 3, 'created_at' => '2026-09-24T03:00:00Z' },
                   { 'id' => 2, 'created_at' => '2026-09-24T02:00:00Z' },
                   { 'id' => 1, 'created_at' => '2026-09-24T01:00:00Z' }]
    statuses = { 4 => [status('failure')], 3 => [status('inactive', 'https://gone.example')],
                 2 => [status('success')], 1 => [status('success', 'https://live.example')] }

    assert_equal 'https://live.example', resolve(deployments, statuses)['deployment']
  end

  def test_auto_records_none_when_the_head_has_no_live_deployment
    assert_equal 'none', resolve([], {})['deployment']
    assert_equal 'none', resolve([{ 'id' => 1, 'created_at' => 'x' }], { 1 => [] })['deployment']
  end

  # https://github.com/shakacode/shaka/issues/495: an empty lookup read like a repository that deploys nothing.
  def test_auto_names_the_head_it_found_no_deployment_for
    assert_equal({ 'deployment' => 'none', 'deployment_not_found_for' => HEAD }, resolve([], {}))
  end

  def test_a_full_page_without_a_live_deployment_is_not_reported_as_none
    deployments = Array.new(100) { |index| { 'id' => index + 1, 'created_at' => format('%03d', index) } }
    statuses = deployments.to_h { |deployment| [deployment['id'], [status('failure')]] }

    error = assert_raises(Shaka::Error) { resolve(deployments, statuses) }
    assert_includes error.message, 'deployment: auto'
  end

  def test_a_supplied_url_or_none_is_left_alone_without_reading_github
    github = RecordedGitHub.new([], {})
    %w[https://preview.example none].each do |value|
      assert_equal({ 'deployment' => value }, Shaka::DeploymentLink.resolve({ 'deployment' => value }, github))
    end
    assert_empty github.reads
  end
end
