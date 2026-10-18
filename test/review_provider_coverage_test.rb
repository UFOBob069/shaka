# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'reviewer_command_fixture'
require 'shaka/reviewer_selection'
require 'shaka/review_coverage'
require 'shaka/repository_config'
require 'shaka/seam/field_classifier'

# review.provider_coverage runs one local reviewer per listed provider in place of
# review.local_review_count, and names each listed provider that could not review as a gap.
class ReviewProviderCoverageTest < Minitest::Test
  include ReviewerCommandFixture

  CLAUDE = { 'provider' => 'anthropic', 'model_family' => 'claude' }.freeze
  CODEX = { 'provider' => 'openai', 'model_family' => 'codex' }.freeze
  GROK = { 'provider' => 'xai', 'model_family' => 'grok' }.freeze
  PAIR = [CLAUDE, CODEX].freeze
  BOTH = %w[anthropic openai].freeze

  def test_without_coverage_the_count_chooses_and_nothing_is_a_gap
    result = choose(['anthropic/claude'], coverage: [])

    assert_equal ['openai/codex'], result.fetch('reviewers')
    assert_empty gaps(result, [])
  end

  # A different provider still goes first; the rest follow the reviewer list.
  def test_runs_one_reviewer_per_listed_provider
    assert_equal %w[openai/codex anthropic/claude], choose(['anthropic/claude']).fetch('reviewers')
    assert_equal %w[anthropic/claude openai/codex], choose(['openai/codex']).fetch('reviewers')
    assert_empty gaps(choose(['openai/codex']))
  end

  def test_a_listed_reviewer_outside_coverage_does_not_run
    result = choose(['anthropic/claude'], coverage: ['anthropic'], reviewers: [GROK, CLAUDE])

    assert_equal ['anthropic/claude'], result.fetch('reviewers')
  end

  def test_an_unusable_entry_gives_way_to_the_next_from_its_provider
    other = { 'provider' => 'openai', 'model_family' => 'other' }
    result = choose(['anthropic/claude'], reviewers: [CODEX, other, CLAUDE], unavailable: ['openai/codex'])

    assert_equal %w[openai/other anthropic/claude], result.fetch('reviewers')
  end

  # Writing a change is not reviewing it, so the implementing provider can still be a gap.
  def test_a_missing_cli_and_an_unavailable_reviewer_name_their_reason
    not_set_up = choose(['openai/codex'], not_set_up: ['openai/codex'])
    unavailable = choose(['openai/codex'], unavailable: ['openai/codex'])

    assert_equal ['anthropic/claude'], not_set_up.fetch('reviewers')
    assert_equal [gap('openai', Shaka::ReviewCoverage::NOT_SET_UP)], gaps(not_set_up)
    assert_equal [gap('openai', Shaka::ReviewCoverage::UNAVAILABLE)], gaps(unavailable)
  end

  def test_an_unlisted_provider_is_a_gap
    result = choose(['anthropic/claude'], reviewers: [CLAUDE])

    assert_equal [gap('openai', Shaka::ReviewCoverage::NOT_LISTED)], gaps(result)
  end

  def test_provider_names_fold_case
    coverage = %w[Anthropic OPENAI]

    assert_empty gaps(choose(['anthropic/claude'], coverage:), coverage)
  end

  def test_the_command_runs_both_providers_and_refuses_a_task_count
    with_repository do |root|
      set_review(root, 'provider_coverage' => BOTH)
      result = reviewer(root, '--implementer', 'anthropic/claude')
      _, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root, '--implementer', 'anthropic/claude',
                                        '--count', '1')

      assert_equal %w[openai/codex anthropic/claude], result.fetch('reviewers')
      assert_empty result.fetch('provider_coverage').fetch('gaps')
      refute_predicate status, :success?
      assert_includes error, '--count does not apply'
    end
  end

  def test_the_seam_rejects_malformed_coverage
    [['openai/codex'], 'openai', %w[openai OpenAI], [' openai']].each do |value|
      error = assert_raises(Shaka::Error, value.inspect) { validate('provider_coverage' => value) }

      assert_includes error.message, 'review.provider_coverage'
    end
  end

  def test_the_seam_rejects_coverage_with_a_count
    error = assert_raises(Shaka::Error) { validate('provider_coverage' => BOTH, 'local_review_count' => 2) }

    assert_includes error.message, 'remove review.local_review_count'
    validate('provider_coverage' => [], 'local_review_count' => 2)
  end

  def test_the_command_refuses_a_seam_with_malformed_coverage
    with_repository do |root|
      set_review(root, 'provider_coverage' => ['openai/codex'])
      _, error, status = Open3.capture3(COMMAND, 'reviewer', '--root', root, '--implementer', 'anthropic/claude')

      refute_predicate status, :success?
      assert_includes error, 'review.provider_coverage must be a list of provider names'
    end
  end

  def test_migration_retains_coverage
    data = { 'version' => 1, 'merge' => { 'preference' => 'ask' },
             'review' => { 'required' => 'none', 'provider_coverage' => BOTH } }
    result = Shaka::Seam::FieldClassifier.new(data).call

    assert_empty result.blocking
    assert_equal BOTH, result.established.dig('review', 'provider_coverage')
  end

  private

  def gap(provider, reason) = { 'provider' => provider, 'reason' => reason }

  def validate(review) = Shaka::ReviewCoverage.validate!(review)

  def set_review(root, values)
    path = File.join(root, '.agents/agent-workflow.yml')
    settings = YAML.safe_load_file(path)
    settings['review'].merge!(values)
    File.write(path, YAML.dump(settings))
  end

  def gaps(selection, coverage = BOTH) = Shaka::ReviewCoverage.coverage(coverage, selection).fetch('gaps')

  # Composes coverage with selection the way `shaka reviewer` does.
  def choose(implementers, coverage: BOTH, reviewers: PAIR, unavailable: [], not_set_up: [])
    usable = ->(entry) { !identities(unavailable + not_set_up).include?(entry.slice('provider', 'model_family')) }
    Shaka::ReviewerSelection.new(
      reviewers: Shaka::ReviewCoverage.candidates(reviewers, coverage, usable), implementers: identities(implementers),
      unavailable: identities(unavailable), not_set_up: identities(not_set_up),
      count: Shaka::ReviewCoverage.count('provider_coverage' => coverage)
    ).call
  end

  def identities(list) = list.map { |text| Shaka::ReviewerSelection.parse(text) }
end
