# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/github'
require 'shaka/local_review'

module EvidenceHistoryFixture
  IDENTITY = "🤖 Claude Code · Anthropic · observed-model · high\n\n"

  class GitHub < Shaka::GitHub
    attr_reader :comments, :writes
    attr_accessor :changed, :failure, :rendering_failure

    def initialize(comments)
      super('example/test', '1')
      @comments = comments.to_h { |comment| [comment['id'], comment] }
      @writes = []
      @reads = Hash.new(0)
    end

    def viewer_login = 'ada'

    def verify_rendering(_body, **)
      rendering_failure ? '<details></details><p>Outside the archive.</p>' : '<details><p>Rendered.</p></details>'
    end

    def api(path, method: 'GET', fields: {})
      id = path.split('/').last.to_i
      row = comments[id] || raise(Shaka::Error, 'Not Found')
      method == 'PATCH' ? update(id, row, fields.fetch(:body)) : read(id, row)
      row.dup
    end

    def update(id, row, body)
      raise Shaka::Error, 'Update failed' if failure

      @writes << id
      row['body'] = body
    end

    def read(id, row)
      @reads[id] += 1
      row['body'] += "\nLater edit" if changed && @reads[id] == 2
    end
  end

  def comment(id, body: "## Visual check at `abc1234`\n\n![After](https://example.test/a.png)\n", login: 'ada', pull: 1)
    { 'id' => id, 'created_at' => "2026-10-11T00:00:0#{id}Z", 'user' => { 'login' => login },
      'issue_url' => "https://api.github.com/repos/example/test/issues/#{pull}", 'body' => "#{IDENTITY}#{body}" }
  end

  def collapse(github, ids, current)
    Shaka::EvidenceHistory.new(github).collapse(ids, current:)
  end

  def url(id) = "https://github.com/example/test/pull/1#issuecomment-#{id}"

  def assert_folded(body, current)
    assert body.start_with?("#{IDENTITY}#{Shaka::EvidenceHistory::MARKER} #{url(current)}\n\n<details>\n")
    assert_includes body, "<summary>Earlier evidence</summary>\n\n## Visual check at `abc1234`"
    assert body.end_with?("</details>\n")
    assert_equal 1, body.scan('<details>').size
  end
end

class EvidenceHistoryTest < Minitest::Test
  include EvidenceHistoryFixture

  def test_selected_earlier_comments_fold_under_a_pointer_to_the_current_one
    github = GitHub.new([comment(1), comment(2), comment(3)])
    report = collapse(github, [1, 2], 3)

    assert_equal({ 'collapsed' => [1, 2], 'unavailable' => [] }, report)
    [1, 2].each { |id| assert_folded(github.comments[id]['body'], 3) }
    refute_includes github.comments[3]['body'], '<details>'
  end

  def test_a_folded_comment_retargets_to_a_newer_current_without_nesting
    github = GitHub.new([comment(1), comment(2), comment(3)])
    collapse(github, [1], 2)

    assert_equal [1, 2], collapse(github, [1, 2], 3)['collapsed']
    assert_folded(github.comments[1]['body'], 3)
  end

  def test_repeating_a_fold_changes_nothing
    github = GitHub.new([comment(1), comment(2)])
    collapse(github, [1], 2)
    report = collapse(github, [1], 2)

    assert_empty report['collapsed']
    assert_empty report['unavailable']
    assert_equal [1], github.writes
  end

  def test_comments_outside_this_accounts_ai_evidence_on_this_pull_request_stay_intact
    github = GitHub.new(unowned_comments + [comment(4), comment(5)])
    report = collapse(github, [1, 2, 3, 5, 6], 4)

    assert_empty report['collapsed'] + github.writes
    assert_equal 5, report['unavailable'].size
    assert_includes report['unavailable'], 'Comment 5: Selected comment is not earlier than the current one.'
  end

  def unowned_comments
    [comment(1, login: 'someone-else'), comment(2).merge('body' => 'Human discussion'), comment(3, pull: 7)]
  end

  def test_an_unusable_current_comment_leaves_every_selection_intact
    [comment(2, login: 'someone-else'), comment(2).merge('body' => 'Human discussion')].each do |current|
      github = GitHub.new([comment(1), current])
      report = collapse(github, [1], 2)

      assert_empty report['collapsed']
      refute_empty report['unavailable']
      assert_empty github.writes
    end
  end

  def test_a_folded_comment_cannot_be_the_current_one
    github = GitHub.new([comment(1), comment(2), comment(3)])
    collapse(github, [2], 3)
    report = collapse(github, [1], 2)

    assert_includes report['unavailable'].join, 'already folded'
    refute_includes github.comments[1]['body'], '<details>'
  end

  def test_changed_bodies_failed_updates_and_escaping_archives_are_reported
    %i[changed failure rendering_failure].each do |problem|
      github = GitHub.new([comment(1), comment(2)])
      github.public_send("#{problem}=", true)
      report = collapse(github, [1], 2)

      assert_empty report['collapsed']
      refute_empty report['unavailable']
    end
  end
end

class EvidenceCollapseCommandTest < Minitest::Test
  include EvidenceHistoryFixture

  def test_command_folds_the_selected_comments
    github = GitHub.new([comment(1), comment(2)])
    out, = capture_io do
      assert_equal 0, run_collapse(github, '--superseded', '1', '--current', '2')
    end
    assert_equal [1], JSON.parse(out)['collapsed']
  end

  def test_command_returns_nonzero_when_a_selection_is_refused
    github = GitHub.new([comment(1, login: 'someone-else'), comment(2)])
    out, = capture_io do
      assert_equal 1, run_collapse(github, '--superseded', '1', '--current', '2')
    end
    refute_empty JSON.parse(out)['unavailable']
  end

  def test_command_refuses_incomplete_or_mixed_selections
    github = GitHub.new([comment(1), comment(2)])
    [%w[--superseded 1], %w[--current 2],
     %w[--superseded 1 --current 2 --bot-comment 3 --head] + ['a' * 40]].each do |flags|
      _out, err = capture_io { assert_equal 1, run_collapse(github, *flags) }
      assert_includes err, 'shaka: invalid argument'
    end
    assert_empty github.writes
  end

  def run_collapse(github, *flags)
    Shaka::LocalReview.run(['collapse', 'example/test', '1', *flags], github:)
  end
end
