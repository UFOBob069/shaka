# frozen_string_literal: true

require_relative 'publication_test'
require_relative 'handoff_helper'

# https://github.com/shakacode/shaka/pull/543 required only a summary, so its description left the
# maintainer to infer the goal, and its check table listed commands without saying what went unproven.
class PublicationIntentVerificationTest < Minitest::Test
  def render(**changes)
    Shaka::Publication.description(PublicationRegressionTest.new(name).description_content(**changes))
  end

  def test_intent_and_verification_render_each_field_on_its_own_line
    rendered = render

    intent = "## Intent\n\n**Why:** #{INTENT['why']}\n\n**Scope:** #{INTENT['scope']}\n\n" \
             "**Leaves out:** #{INTENT['leaves_out']}\n\n**Safe because:** #{INTENT['safe_because']}\n\n" \
             '**Review effort:** 2 of 5, easy: skim the diff.'
    verification = "## Verification\n\n#{Shaka::VerificationGates::UNKNOWN}\n\n" \
                   "- #{VERIFICATION['checks'].first}\n\n" \
                   "**Not verified:** #{VERIFICATION['not_verified']}"
    assert_includes rendered, intent
    assert_includes rendered, verification
  end

  def test_intent_and_verification_follow_the_links_and_precede_every_section
    rendered = render('sections' => [{ 'heading' => 'Detail', 'body' => 'More.' }])

    assert_operator rendered.index('[Code Walkthrough]('), :<, rendered.index('## Intent')
    assert_operator rendered.index('## Intent'), :<, rendered.index('## Verification')
    assert_operator rendered.index('## Verification'), :<, rendered.index('## Detail')
  end

  def test_the_check_table_is_optional
    rendered = render('table' => nil)

    refute_includes rendered, '| Check |'
    assert_includes rendered, '## Verification'
  end

  def test_each_intent_field_is_required
    INTENT.each_key do |field|
      error = assert_raises(Shaka::Error) { render('intent' => INTENT.except(field)) }
      assert_includes error.message, "intent #{field}"
    end
  end

  def test_a_check_without_a_link_or_command_is_refused
    error = assert_raises(Shaka::Error) do
      render('verification' => VERIFICATION.merge('checks' => ['All tests passed.']))
    end
    assert_includes error.message, 'Markdown link or a code span'
  end

  def test_a_check_may_cite_a_command_or_a_link
    checks = ['Ran `bin/validate`: 3,047 tests, 0 failures.',
              'Published on [#539](https://github.com/shakacode/shaka/pull/539): all 7 commits linked.',
              'Replied on [#553](<https://github.com/shakacode/shaka/pull/553#discussion_r1>): fixed.']
    rendered = render('verification' => VERIFICATION.merge('checks' => checks))

    assert_includes rendered, checks.map { |check| "- #{check}" }.join("\n")
  end

  # A bug-fix PR put the cause in Why and left the symptom unstated.
  def test_a_bug_fix_names_its_root_cause_after_why
    cause = 'The booking link covered the underlined price.'
    rendered = render('intent' => INTENT.merge('root_cause' => cause))

    assert_includes rendered, "**Why:** #{INTENT['why']}\n\n**Root cause:** #{cause}\n\n**Scope:**"
  end

  def test_root_cause_is_optional_but_not_blank
    refute_includes render, 'Root cause'
    error = assert_raises(Shaka::Error) { render('intent' => INTENT.merge('root_cause' => ' ')) }
    assert_includes error.message, 'intent root_cause'
  end

  # The reviewer sees from the blast radius how hard to look, like a heart-rate zone.
  def test_review_effort_names_its_zone
    rendered = render('intent' => INTENT.merge('review_effort' => 5))

    assert_includes rendered, '**Review effort:** 5 of 5, all out: review every line, reproduce it, and ' \
                              'ask a second reviewer.'
  end

  def test_review_effort_must_be_a_whole_number_from_one_to_five
    [0, 6, '3', 2.5].each do |effort|
      error = assert_raises(Shaka::Error) { render('intent' => INTENT.merge('review_effort' => effort)) }
      assert_includes error.message, 'review_effort'
    end
  end

  # A draft published before validation has nothing to cite yet, so it says why instead.
  def test_an_unfinished_description_may_list_no_checks
    rendered = render('wip' => HandoffFixtures::WIP,
                      'verification' => { 'checks' => [], 'not_verified' => 'Validation has not run yet.' })

    assert_includes rendered, "## Verification\n\n#{Shaka::VerificationGates::UNKNOWN}\n\n" \
                              '**Not verified:** Validation has not run yet.'
  end

  def test_one_to_three_checks_are_allowed
    [[], Array.new(4, VERIFICATION['checks'].first)].each do |checks|
      error = assert_raises(Shaka::Error) { render('verification' => VERIFICATION.merge('checks' => checks)) }
      assert_includes error.message, '1 to 3'
    end
  end

  def test_the_not_verified_line_is_required
    error = assert_raises(Shaka::Error) { render('verification' => VERIFICATION.except('not_verified')) }
    assert_includes error.message, 'verification not_verified'
  end

  def test_missing_intent_or_verification_is_refused
    %w[intent verification].each do |key|
      error = assert_raises(Shaka::Error) { render(key => nil) }
      assert_includes error.message, "requires #{key}"
    end
  end

  def test_a_walkthrough_needs_neither
    content = { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.', 'head' => 'a' * 40 }

    refute_includes Shaka::Publication.walkthrough(content), '## Intent'
  end
end
