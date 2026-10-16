# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'shaka/claim'
require_relative 'claim_helpers'

# A task given as a sentence has no work item, so claim names it by its description slug.
class ClaimAdHocTest < Minitest::Test
  include ClaimHelpers

  HEADS = "aaa\trefs/heads/jg-claude/ad-hoc-button-counter\n" \
          "bbb\trefs/heads/jg-codex/ad-hoc-other-task\n" \
          "ccc\trefs/heads/jg-codex/42-button-counter\n"

  def test_reports_the_template_with_the_fixed_issue_placeholder_and_the_slug
    result = ad_hoc('button-counter', prs: [], branches: '')

    assert_nil result.fetch('query')
    assert_equal 'button-counter', result.fetch('description')
    assert_equal '{login}-{host}/ad-hoc-button-counter', result.fetch('branch_name')
    refute result.fetch('collision')
  end

  def test_a_remote_branch_with_the_same_slug_is_a_collision_and_other_ad_hoc_slugs_are_not
    result = ad_hoc('button-counter', prs: [], branches: HEADS)

    assert result.fetch('collision')
    assert_equal ['jg-claude/ad-hoc-button-counter'], result.fetch('branches')
  end

  def test_an_open_pull_request_on_a_same_slug_branch_is_a_collision
    prs = [{ 'number' => 7, 'title' => 'Counter', 'url' => 'https://example/7',
             'headRefName' => 'jg-cursor/ad-hoc-button-counter' },
           { 'number' => 8, 'title' => 'Mentions button-counter', 'url' => 'https://example/8',
             'headRefName' => 'jg-cursor/ad-hoc-other', 'body' => 'button-counter' }]
    result = ad_hoc('button-counter', prs: prs, branches: '')

    assert_equal([7], result.fetch('pull_requests').map { |pr| pr.fetch('number') })
  end

  def test_follows_a_repository_template
    result = ad_hoc('button-counter', prs: [], branches: "aaa\trefs/heads/feature/ad-hoc/button-counter\n",
                                      branch_name: 'feature/{issue}/{description}')

    assert_equal 'feature/ad-hoc/button-counter', result.fetch('branch_name')
    assert_equal ['feature/ad-hoc/button-counter'], result.fetch('branches')
  end

  def test_refuses_a_template_that_cannot_hold_the_description
    error = assert_raises(Shaka::Error) do
      ad_hoc('button-counter', prs: [], branches: '', branch_name: '{login}/{issue}')
    end

    assert_includes error.message, '{description}'
  end

  def test_refuses_a_description_that_is_not_a_lowercase_slug
    ['Button-counter', 'button counter', '-button', 'button--counter', 'button-', 'a/b', ''].each do |slug|
      error = assert_raises(Shaka::Error) { ad_hoc(slug, prs: [], branches: '') }

      assert_includes error.message, 'lowercase', slug
    end
  end

  def test_cli_runs_without_a_work_item
    stdout, status = capture_cli(['--description', 'button-counter'], prs: [], branches: HEADS)

    assert_equal 0, status
    assert JSON.parse(stdout).fetch('collision')
  end

  def test_cli_refuses_a_work_item_or_tracker_branch_alongside_a_description
    [['42', '--description', 'button-counter'],
     ['--description', 'button-counter', '--branch', 'eng-1-counter'],
     []].each do |arguments|
      _stdout, status = capture_cli(arguments, prs: [], branches: '')

      assert_equal 1, status, arguments.inspect
    end
  end

  private

  def ad_hoc(slug, prs:, branches:, branch_name: nil)
    Shaka::Claim.new(query: Shaka::Claim::Description.new(slug:), root: Dir.pwd,
                     runner: runner(prs: prs, branches: branches), branch_name: branch_name).result
  end
end
