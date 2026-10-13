# frozen_string_literal: true

# Proves `shaka description --comments PATH` publishes the human comment list from that file.

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'cli_opening_check_fakes'
require 'json'

class CliDescriptionHumanCommentsTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'The description now lists what people wrote.'
  REPO = { 'repo' => { 'full_name' => 'owner/repo' } }.freeze
  HEAD = 'c' * 40
  COMMENT = { 'id' => 1, 'author' => 'bob', 'body' => 'Please split this PR.',
              'url' => 'https://github.com/owner/repo/pull/1#issuecomment-1' }.freeze
  LONG = COMMENT.merge('body' => 'Please split this pull request into the reader change and the list, ' \
                                 'so each can be reviewed alone.').freeze

  def test_description_publishes_the_human_comments_in_the_file
    Dir.mktmpdir do |dir|
      _output, error, status = run_with_comments(dir, packet(HEAD))

      assert_predicate status, :success?, error
      assert_includes File.read(File.join(dir, 'published.md')),
                      '| **Reviewer** [bob](https://github.com/bob) | [“Please split this PR\\.”]' \
                      '(https://github.com/owner/repo/pull/1#issuecomment-1) | — | **No reply** |'
    end
  end

  def test_a_longer_comment_without_the_agent_s_summary_publishes_nothing
    Dir.mktmpdir do |dir|
      _output, error, status = run_with_comments(dir, packet(HEAD, LONG))

      refute_predicate status, :success?
      assert_includes error, "needs a one-line summary for each longer human comment: #{COMMENT['url']}"
      refute_path_exists File.join(dir, 'published.md')
    end
  end

  def test_the_agent_s_summary_in_the_content_file_stands_in_for_a_longer_comment
    Dir.mktmpdir do |dir|
      summary = { 'human_comment_summaries' => { COMMENT['url'] => 'Asks to split the PR in two.' } }
      _output, error, status = run_with_comments(dir, packet(HEAD, LONG), summary)

      assert_predicate status, :success?, error
      assert_includes File.read(File.join(dir, 'published.md')), "[Asks to split the PR in two\\.](#{COMMENT['url']})"
    end
  end

  def test_comments_read_at_an_earlier_head_publish_nothing
    Dir.mktmpdir do |dir|
      _output, error, status = run_with_comments(dir, packet('d' * 40))

      refute_predicate status, :success?
      assert_includes error, 'Run `shaka comments` for that head'
      refute_path_exists File.join(dir, 'published.md')
    end
  end

  def test_a_list_written_into_the_content_file_is_refused
    Dir.mktmpdir do |dir|
      _output, error, status = run_with_comments(dir, packet(HEAD), 'human_comments' => packet(HEAD))

      refute_predicate status, :success?
      assert_includes error, 'human_comments comes from --comments, not the content file.'
      refute_path_exists File.join(dir, 'published.md')
    end
  end

  def test_the_flag_belongs_to_description
    Dir.mktmpdir do |dir|
      _output, error, status = Open3.capture3({ 'HOME' => dir }, COMMAND, 'resolve', 'owner/repo', '1',
                                              '--thread', 'T1', '--comments', File.join(dir, 'comments.json'))

      refute_predicate status, :success?
      assert_includes error, '--comments is only for description.'
    end
  end

  private

  def packet(head, comment = COMMENT)
    { 'visibility' => 'private', 'head' => head, 'review_threads' => [], 'trust_sources' => [],
      'excluded_interactions' => [], 'issue_comments' => [comment], 'review_summaries' => [],
      'inline_comments' => [] }
  end

  def run_with_comments(dir, comments, content = {})
    write_fake_commands(dir)
    File.write(File.join(dir, 'content.json'), JSON.generate(description_content.merge(content)))
    File.write(File.join(dir, 'comments.json'), JSON.generate(comments))
    Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir }, COMMAND, 'description',
                   'owner/repo', '1', '--root', ROOT, '--content-file', File.join(dir, 'content.json'),
                   '--comments', File.join(dir, 'comments.json'))
  end

  def fake_gh
    pull = { 'body' => '', 'number' => 1, 'user' => { 'login' => 'ann' }, 'head' => REPO.merge('sha' => HEAD),
             'base' => REPO, 'changed_files' => 0 }
    encoded = JSON.generate(pull).unpack1('H*')
    replaced = super.sub("puts JSON.generate('body' => '', 'head' => { 'sha' => 'c' * 40 }, 'changed_files' => 0)",
                         "puts [#{encoded.dump}].pack('H*')")
    raise 'fake gh pull response was not replaced' if replaced == super

    replaced
  end
end
