# frozen_string_literal: true

require_relative 'cli_description_decisions_test'

# The published description carries the timings the helper read from the label timeline.
class CliDescriptionTimingsTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include CliOpeningCheckFakes
  include CliDescriptionDecisionsRun

  COMMAND = CliDescriptionDecisionsTest::COMMAND
  ROOT = CliDescriptionDecisionsTest::ROOT
  SUMMARY = 'Timings sit beside usage.'

  def test_description_shows_the_timings_read_from_the_label_timeline
    with_repository do |root|
      commit(root)
      Dir.mktmpdir do |dir|
        _output, error, status = run_description(dir, root:, decisions: [])

        assert_predicate status, :success?, error
        published = File.read(File.join(dir, 'published.md'))
        assert_includes published, '**Totals:** 10m between checkpoints'
        assert_match(/\| Waiting on a person: answer \| 2026-10-18 08:10 \| [^|]+ \(resumed\) \|/, published)
      end
    end
  end

  private

  def fake_gh = DESCRIPTION_GH
end
