# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/public_comments'

class GitHubLoginTest < Minitest::Test
  def test_accepts_github_login_shape
    assert_equal %w[a mixed-case], Shaka::PublicComments::GitHubLogin.valid(%w[a mixed-case])
  end

  def test_rejects_consecutive_or_edge_hyphens
    assert_empty Shaka::PublicComments::GitHubLogin.valid(%w[-start end- two--hyphens])
  end

  def test_rejects_login_longer_than_thirty_nine_characters
    assert_equal ['a' * 39], Shaka::PublicComments::GitHubLogin.valid(['a' * 39, 'a' * 40])
  end

  def test_names_a_graphql_bot_author_by_its_rest_login_once
    %w[shaka-app shaka-app[bot]].each do |login|
      assert_equal 'shaka-app[bot]', Shaka::PublicComments::GitHubLogin.author('__typename' => 'Bot', 'login' => login)
    end
    assert_equal 'alice', Shaka::PublicComments::GitHubLogin.author('__typename' => 'User', 'login' => 'alice')
  end
end
