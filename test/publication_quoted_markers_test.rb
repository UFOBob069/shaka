# frozen_string_literal: true

require_relative 'publication_test'
require_relative 'github_helper'
require_relative 'usage_records_test'
require 'shaka/github/squash_comment'
require 'shaka/usage/records'

# https://github.com/shakacode/shaka/issues/605: a description quoting one of Shaka's own
# markers published once, then left every reader of the managed region failing.
class PublicationQuotedMarkersTest < Minitest::Test
  include GitHubHelper
  include UsageRecordsFixture

  MARKERS = [
    Shaka::Publishing::OPEN_MARK, Shaka::Publishing::CLOSE_MARK,
    Shaka::MergeWarningRegion::OPEN, Shaka::MergeWarningRegion::CLOSE,
    Shaka::ProvenanceHistory::PREFIX.strip, Shaka::HumanComments::OPEN_MARK, Shaka::HumanComments::CLOSE_MARK,
    Shaka::PublicationSections::MARKER, Shaka::StepsBesidesMerging::MARKER,
    Shaka::UsageRecords::BEGIN_PREFIX.strip, Shaka::UsageRecords::END_MARK,
    Shaka::SquashComment::SQUASH_MARK, '<!-- shaka:reply:fix-1 -->'
  ].freeze

  def content(**changes) = PublicationRegressionTest.new('content').description_content(**changes)

  def test_a_summary_quoting_any_shaka_marker_is_refused_naming_it
    MARKERS.each do |marker|
      error = assert_raises(Shaka::Error, marker) do
        Shaka::Publication.description(content('summary' => "Moves the `#{marker}` check."))
      end
      assert_includes error.message, marker[%r{\A<!-- /?shaka:[\w:.-]*}], marker
      assert_includes error.message, 'summary'
    end
  end

  def test_a_marker_in_nested_content_names_where_it_was_found
    sections = [{ 'heading' => 'Outcome', 'body' => 'Quotes <!-- shaka:begin --> here.' }]
    error = assert_raises(Shaka::Error) { Shaka::Publication.description(content('sections' => sections)) }
    assert_includes error.message, 'sections[0].body'
  end

  def test_a_refused_description_writes_nothing_to_the_pull_request
    github = client(response({ 'id' => 1, 'number' => 42, 'body' => '' }))
    quoted = content('summary' => 'Moves the `<!-- shaka:end -->` marker check.')
    assert_raises(Shaka::Error) { github.description { Shaka::Publication.description(quoted) } }
    assert_equal 1, @calls.size, 'only the pull request read may happen'
  end

  # Break: checking the carried reports refused every republish that kept earlier usage.
  def test_usage_carried_from_the_earlier_body_still_renders
    earlier = existing(record('codex', 'codex-review', responses: %w[r1], sources: ['s9'], contribution: 'review'))
    carried, = Shaka::UsageRecords.carry(content, earlier)
    assert_includes carried.dig('usage', 'carried'), Shaka::UsageRecords::END_MARK
    assert_includes Shaka::Publication.description(carried), 'codex-review'
  end

  def test_marker_names_without_comment_delimiters_still_render
    assert_includes Shaka::Publication.description(content('summary' => 'Moves the `shaka:end` check.')),
                    '`shaka:end`'
  end
end
