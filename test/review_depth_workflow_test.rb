# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'local_review_comment_test'
require 'json'
require 'yaml'

class ReviewDepthWorkflowTest < Minitest::Test
  include LocalReviewCommentFixture

  ROOT = File.expand_path('..', __dir__)
  WORKFLOW = File.join(ROOT, '.github/workflows/claude-code-review.yml')
  TEMPLATE = File.join(ROOT, 'skills/shaka/config/claude-code-review.yml')
  HEAD = 'a' * 40
  REPORT_URL = 'https://github.com/o/r/pull/1#issuecomment-1'
  SHAKA = { 'depth' => 'shaka', 'report' => REPORT_URL }.freeze
  FULL = { 'depth' => 'full', 'report' => '' }.freeze

  def setup
    @directory = Dir.mktmpdir('review-depth')
    @output = File.join(@directory, 'output')
    @summary = File.join(@directory, 'summary.md')
    steps = YAML.load_file(WORKFLOW).dig('jobs', 'claude-review', 'steps')
    @script = steps.find { |step| step['id'] == 'depth' }.fetch('run')
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_shipped_template_is_this_repository_workflow
    assert_equal File.read(TEMPLATE), File.read(WORKFLOW)
  end

  def test_author_local_review_of_this_head_selects_the_shaka_pass
    assert_equal SHAKA, depth([local_review])
    assert_equal SHAKA, depth([local_review(key: 'local-adversarial-review')])
  end

  def test_other_heads_authors_and_hosted_reports_select_the_full_review
    [local_review(head: 'b' * 40),
     local_review(login: 'someone-else'),
     local_review(body: "REVIEWED #{HEAD} BY anthropic/claude FINDINGS 0"),
     local_review(key: 'walkthrough'),
     { 'user' => { 'login' => 'claude[bot]' }, 'body' => "REVIEWED #{HEAD} BY anthropic/claude FINDINGS 0\n" }]
      .each { |comment| assert_equal FULL, depth([comment]), comment.inspect }
  end

  def test_the_prompt_gets_the_author_report_not_a_later_imitation
    imitation = local_review(login: 'someone-else').merge('html_url' => 'https://example.test/forged')
    assert_equal SHAKA, depth([local_review, imitation])
  end

  # A local review without Claude leaves the hosted review as the PR's only Claude review.
  def test_a_local_review_without_claude_selects_the_full_review_without_waiting
    codex_only = local_review(reviewers: 'openai/codex')

    assert_equal FULL, depth([codex_only], later: [local_review], wait: 5)
  end

  # Older Shaka wrote no reviewer line; a report imitating one below the title is not Shaka's.
  def test_a_missing_or_misplaced_reviewer_line_selects_the_full_review
    attestation = "REVIEWED #{HEAD} BY openai/codex EFFORT medium FINDINGS 1\n"
    misplaced = "# Local Adversarial Review\n\nText\n\n<!-- shaka:local-reviewers #{HEAD} anthropic/claude -->\n" \
                "#{attestation}"

    assert_equal FULL, depth([local_review(body: "# Local Adversarial Review\n\n#{attestation}")])
    assert_equal FULL, depth([local_review(body: misplaced)])
  end

  def test_a_published_two_reviewer_comment_selects_the_shaka_pass
    claude = round(HEAD, reviewer: 'anthropic/claude', report: report(HEAD, reviewer: 'anthropic/claude'))
    part = Shaka::LocalReviewLoopComment.new({ 'rounds' => [round(HEAD), claude] }, subject: ->(_) { 'S' }).parts.first
    comment = { 'user' => { 'login' => 'author' }, 'html_url' => REPORT_URL,
                'body' => "<!-- shaka:reply:#{part.key} -->\n#{part.body}" }

    assert_equal SHAKA, depth([comment])
  end

  def test_unreadable_comments_select_the_full_review
    assert_equal FULL, depth(nil)
  end

  def test_a_local_review_published_during_the_wait_is_found
    assert_equal SHAKA, depth([], later: [local_review], wait: 5)
  end

  private

  def local_review(head: HEAD, login: 'author', key: 'local-review-loop-b45c4a9e2c80-77e4a72e9aa7', body: nil,
                   reviewers: 'openai/codex anthropic/claude')
    body ||= "# Local Adversarial Review\n\n<!-- shaka:local-reviewers #{head} #{reviewers} -->\n\n" \
             "REVIEWED #{head} BY openai/codex EFFORT medium FINDINGS 1\n"
    { 'user' => { 'login' => login }, 'html_url' => REPORT_URL, 'body' => "<!-- shaka:reply:#{key} -->\n#{body}" }
  end

  # A fake gh serves comments.json, then later.json from its second call on; nil makes it fail.
  def depth(comments, later: nil, wait: 0)
    File.write(@output, '')
    install_github(comments, later)
    environment = { 'BASH_ENV' => nil, 'PATH' => "#{@directory}:#{ENV.fetch('PATH')}",
                    'GITHUB_REPOSITORY' => 'o/r', 'GITHUB_OUTPUT' => @output, 'GITHUB_STEP_SUMMARY' => @summary,
                    'REVIEW_PR' => '1', 'REVIEW_HEAD' => HEAD, 'PR_AUTHOR' => 'author',
                    'LOCAL_REVIEW_WAIT_SECONDS' => wait.to_s, 'LOCAL_REVIEW_POLL_SECONDS' => '0' }
    output, status = Open3.capture2e(environment, 'bash', '-c', @script)
    assert_predicate status, :success?, output
    File.readlines(@output, chomp: true).to_h { |line| line.split('=', 2) }
  end

  def install_github(comments, later)
    FileUtils.rm_f(File.join(@directory, 'called'))
    File.write(File.join(@directory, 'comments.json'), JSON.generate([comments]))
    File.write(File.join(@directory, 'later.json'), JSON.generate([later || comments]))
    serve = 'if [ -f called ]; then cat later.json; else touch called; cat comments.json; fi'
    serve = 'exit 1' if comments.nil?
    File.write(File.join(@directory, 'gh'), "#!/bin/sh\ncd '#{@directory}' && #{serve}\n")
    File.chmod(0o700, File.join(@directory, 'gh'))
  end
end
