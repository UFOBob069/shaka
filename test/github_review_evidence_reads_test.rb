# frozen_string_literal: true

require_relative 'github_helper'

class GitHubReviewEvidenceReadsTest < Minitest::Test
  include GitHubHelper

  def test_review_evidence_reads_use_fixed_endpoints
    github = client(response([{ 'id' => 1 }]), response({ 'status' => 'ahead', 'files' => [] }))

    assert_equal [{ 'id' => 1 }], github.issue_comments
    assert_equal({ 'status' => 'ahead', 'files' => [] }, github.compare(BASE, HEAD))
    assert_equal ['gh', 'api', 'repos/owner/repo/issues/42/comments?per_page=100&page=1', '--method', 'GET',
                  '--input', '-'], @calls.first.first
    assert_equal ['gh', 'api', "repos/owner/repo/compare/#{BASE}...#{HEAD}", '--method', 'GET', '--input', '-'],
                 @calls.last.first
  end

  def test_compare_refuses_unsafe_endpoints_before_calling_github
    github = client

    [['main', 'main'], ['main..x', HEAD], ['-x', HEAD], ["main\n", HEAD]].each do |from, to|
      assert_raises(Shaka::Error) { github.compare(from, to) }
    end
    assert_empty @calls
  end

  def test_compare_accepts_a_base_branch_as_the_start
    github = client(response({ 'status' => 'ahead', 'files' => [] }))

    github.compare('release/1.x', HEAD)
    assert_equal "repos/owner/repo/compare/release/1.x...#{HEAD}", @calls.first.first[2]
  end

  def test_viewer_login_reads_the_rest_account
    github = client(response({ 'login' => 'octocat' }))

    assert_equal 'octocat', github.viewer_login
    assert_equal 'octocat', github.viewer_login
    assert_equal 1, @calls.size
  end

  def test_viewer_login_names_an_app_installation_token_as_its_bot
    %w[shaka-app shaka-app[bot]].each do |graphql_login|
      github = client(response({ 'message' => 'Resource not accessible by integration' }, status: 1, http_status: 403),
                      response({ 'data' => { 'viewer' => { 'login' => graphql_login } } }))

      assert_equal 'shaka-app[bot]', github.viewer_login
      assert_equal 'graphql', @calls.last.first[2]
    end
  end

  def test_viewer_login_keeps_other_rest_failures
    github = client(response({}, status: 1, http_status: 401))

    assert_equal 401, assert_raises(Shaka::Error) { github.viewer_login }.http_status
    assert_equal 1, @calls.size
  end

  def test_viewer_login_refuses_an_empty_account
    github = client(response({ 'login' => '' }))

    assert_raises(Shaka::Error) { github.viewer_login }
  end
end
