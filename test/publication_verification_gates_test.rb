# frozen_string_literal: true

require_relative 'publication_test'

# The description already receives the validation and review results, so Ruby writes their
# line; the agent's checks are left for proof specific to the change.
class PublicationVerificationGatesTest < Minitest::Test
  HEAD = "abcdef1#{'0' * 33}".freeze
  VALIDATE = { 'kind' => 'validation', 'command' => 'validate', 'status' => 'completed', 'exit_code' => 0 }.freeze
  CLAUDE = { 'kind' => 'review', 'reviewer' => 'anthropic/claude', 'status' => 'completed', 'head' => HEAD }.freeze
  CODEX = { 'kind' => 'review', 'reviewer' => 'openai/codex', 'status' => 'reported', 'head' => HEAD }.freeze

  def render(settings, **changes)
    Shaka::Publication.description(PublicationRegressionTest.new(name).description_content(**changes),
                                   nil, nil, settings)
  end

  def bound(validation: [VALIDATE], review: [CLAUDE])
    checks = { 'validation' => validation, 'review' => review }.transform_values do |results|
      results.map { |result| { 'status' => 'bound', 'original' => result } }
    end
    Shaka::PublicationSettings.new(verdict: { 'status' => 'ready', 'head' => HEAD, 'checks' => checks })
  end

  # Eleven of twelve PRs after #553 spent two of three checks restating validate and local review.
  def test_bound_results_render_one_validation_and_review_line_before_the_checks
    url = 'https://github.com/shakacode/shaka/pull/9#issuecomment-1'
    rendered = render(bound(review: [CLAUDE, CODEX]), 'review' => url)

    line = '**Validation and review:** `validate` passed (exit 0); local review by anthropic/claude, ' \
           "openai/codex (host-reported) ([attestation](#{url})) at `abcdef1`."
    assert_includes rendered, "## Verification\n\n#{line}\n\n- #{VERIFICATION['checks'].first}"
  end

  # Binding accepts any completed run, so a failed validate must not read as a pass.
  def test_a_failed_validation_is_reported_with_its_exit_code
    rendered = render(bound(validation: [VALIDATE.merge('exit_code' => 1)]))

    assert_includes rendered, '`validate` failed (exit 1); local review by anthropic/claude at `abcdef1`.'
  end

  # The first description is published before the review comment exists, so it has no link yet.
  def test_the_line_names_reviewers_without_a_link_before_review_publication
    refute_includes render(bound), '[attestation]'
  end

  def test_without_results_the_line_says_none_were_supplied
    assert_includes render(nil), "## Verification\n\n#{Shaka::VerificationGates::UNKNOWN}\n\n"
  end
end
