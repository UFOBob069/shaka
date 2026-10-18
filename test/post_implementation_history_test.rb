# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/github'
require 'shaka/post_implementation/history'

class PostImplementationHistoryTest < Minitest::Test
  class GitHub < Shaka::GitHub
    attr_reader :comments, :writes
    attr_accessor :changed, :failure, :mismatched, :listing, :rendering_failure

    def initialize(comments)
      super('example/test', '1')
      @comments = comments.to_h { |comment| [comment['id'], comment] }
      @writes = []
      @reads = Hash.new(0)
    end

    def viewer_login = 'ada'

    def issue_comments = listing || comments.values

    def verify_rendering(_body, **)
      rendering_failure ? '<details></details><p>Outside the archive.</p>' : '<details><p>Rendered.</p></details>'
    end

    def api(path, method: 'GET', fields: {})
      id = path.split('/').last.to_i
      row = comments.fetch(id)
      method == 'PATCH' ? update(id, row, fields.fetch(:body)) : read(id, row)
      row.dup
    end

    def update(id, row, body)
      raise Shaka::Error, 'Update failed' if failure

      @writes << [id, body]
      row['body'] = body unless mismatched
    end

    def read(id, row)
      @reads[id] += 1
      row['body'] += "\nHuman edit" if changed && @reads[id] == 2
    end
  end

  def test_older_owned_reports_point_to_newest_with_original_text_preserved
    prior = comment(1)
    latest = comment(2)
    github = GitHub.new([prior, latest, comment(3, login: 'someone-else'),
                         comment(4).merge('body' => 'Human discussion')])
    report = collapse(github, latest)

    assert_equal [1], report['collapsed']
    assert_empty report['unavailable']
    assert_archived(prior['body'], 2)
    assert_equal [[1, prior['body']]], github.writes
  end

  def test_already_collapsed_reports_retarget_without_nesting_or_losing_edits
    github = prepared_history
    prior = github.comments[1]
    prior['body'] += "\nHuman annotation\n"
    newer = comment(3)
    github.comments[3] = newer
    collapse(github, newer)

    assert_archived(prior['body'], 3)
    assert_includes prior['body'], 'Human annotation'
    assert_equal 1, prior['body'].scan('<details>').size
  end

  def test_model_identifier_stays_above_the_pointer_after_collapse_and_retarget
    identity = "🤖 claude · anthropic · observed-model · high\n\n"
    github = prepared_history(body: "#{identity}Original conclusion")
    prior = github.comments[1]
    github.comments[3] = comment(3)
    collapse(github, github.comments[3])

    assert prior['body'].start_with?("#{mark}#{identity}#{Shaka::PostImplementationHistory::MARKER}")
  end

  def test_repeating_the_newest_publication_is_idempotent
    github = prepared_history
    assert_empty collapse(github, github.comments[2])['collapsed']
  end

  def test_retrying_an_old_execution_keeps_it_pointing_to_the_newest
    prior = comment(1)
    latest = comment(2)
    github = GitHub.new([prior, latest])
    collapse(github, prior)

    assert_includes prior['body'], url(2)
    refute_includes latest['body'], '<details>'
  end

  def test_equal_timestamps_order_by_comment_id_and_never_move_a_pointer_backwards
    prior = comment(1)
    latest = comment(2)
    prior['body'] = "#{mark}#{Shaka::PostImplementationHistory::MARKER} #{url(3)}\n\nKept history\n"
    github = GitHub.new([prior, latest])

    assert_empty collapse(github, latest)['collapsed']
    assert_includes prior['body'], url(3)
  end

  def test_archive_preserves_nested_details_and_fenced_examples
    prior = comment(1, body: "<details>kept</details>\n```\n</details>\n```\n")
    latest = comment(2)
    collapse(GitHub.new([prior, latest]), latest)

    assert_includes prior['body'], '<details>kept</details>'
    assert_includes prior['body'], "```\n</details>\n```"
  end

  def test_changed_bodies_and_failed_or_unconfirmed_updates_are_explicit
    %i[changed failure mismatched rendering_failure].each do |problem|
      prior = comment(1)
      latest = comment(2)
      github = GitHub.new([prior, latest])
      github.public_send("#{problem}=", true)
      report = collapse(github, latest)

      assert_empty report['collapsed']
      refute_empty report['unavailable']
      assert_empty github.writes if %i[changed rendering_failure].include?(problem)
    end
  end

  def test_missing_publication_and_bounded_listing_failure_leave_reports_intact
    latest = comment(2)
    github = GitHub.new([comment(1), latest])
    github.listing = []
    refute_empty collapse(github, latest)['unavailable']
    github.define_singleton_method(:issue_comments) { raise Shaka::PublicComments::BoundedList::LimitError, 'Too many pages' }
    refute_empty collapse(github, latest)['unavailable']
    assert_empty github.writes
  end

  private

  def prepared_history(body: 'Original conclusion')
    github = GitHub.new([comment(1, body:), comment(2)])
    collapse(github, github.comments[2])
    github
  end

  def assert_archived(body, latest)
    assert_includes body, url(latest)
    assert_includes body, 'Original conclusion'
    assert body.start_with?(mark)
  end

  def collapse(github, published) = Shaka::PostImplementationHistory.new(github).collapse(published)

  def mark = "<!-- shaka:reply:post-implementation-aaaaaaa-abc12345 -->\n"

  def url(id) = "https://github.com/example/test/pull/1#issuecomment-#{id}"

  def comment(id, body: 'Original conclusion', login: 'ada')
    { 'id' => id, 'created_at' => '2026-09-30T00:00:00Z', 'user' => { 'login' => login }, 'body' => "#{mark}#{body}" }
  end
end

class PostImplementationHistoryTest
  def test_legacy_archive_retargets_without_nesting_or_losing_human_annotations
    older = comment(1, body: "#{Shaka::PostImplementationHistory::LEGACY_MARKER} #{url(2)}\n\n" \
                             "<details>\n<summary>Earlier product validation</summary>\n\n" \
                             "Original conclusion\nHuman annotation\n\n</details>\n")
    newest = comment(3)
    github = GitHub.new([older, newest])
    report = collapse(github, newest)
    assert_empty report['unavailable']
    assert_includes older['body'], "#{Shaka::PostImplementationHistory::MARKER} #{url(3)}"
    assert_includes older['body'], 'Human annotation'
    assert_equal 1, older['body'].scan('<details>').size
  end
end
