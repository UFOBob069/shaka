# frozen_string_literal: true

require_relative 'publication_human_comments_test'
require 'shaka/github'

# What Shaka's own publishers post under the PR author's login must not be listed as that
# person's comment, so these bodies come from the publishers, not from the test.
class HumanCommentsAgentPostsTest < Minitest::Test
  include HumanCommentsFixture

  CONTENT = { 'identity' => { 'agent' => 'Codex' }, 'summary' => 'Removed both placeholders.' }.freeze
  MESSAGE = Struct.new(:headline, :body).new('List human comments (#7)', 'Body.')

  def test_no_post_a_shaka_publisher_writes_is_listed_as_a_person_s_comment
    posts = [reply_as_posted, Shaka::Publication.walkthrough(CONTENT.merge('head' => HEAD)),
             Shaka::SquashComment.body(HEAD, MESSAGE),
             "#{Shaka::WalkthroughHistory::MARKER} #{URL}#pullrequestreview-9\n\n<details>\n\nOld.\n\n</details>"]
    comments = posts.each_with_index.map { |body, index| issue_comment(index + 1, 'ann', body) }

    assert_empty rows(describe(packet(issue_comments: comments)))
  end

  private

  # The body `shaka reply` sends to GitHub: its hidden key line, then the rendered comment.
  def reply_as_posted
    sent = []
    answers = [{ 'body' => '' }, { 'login' => 'ann' }, [], '<p>ok</p>']
    runner = lambda do |_argv, stdin_data:|
      sent << stdin_data
      answer = answers.shift || JSON.parse(stdin_data)
      [answer.is_a?(String) ? answer : JSON.generate(answer), '', Struct.new(:exitstatus).new(0)]
    end
    Shaka::GitHub.new('owner/repo', 7, runner:).reply(body: Shaka::Publication.comment(CONTENT), key: 'fix-1')
    JSON.parse(sent.last).fetch('body')
  end
end
