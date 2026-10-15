# frozen_string_literal: true

require_relative 'publication_test'

# https://github.com/shakacode/shaka/pull/219 merged while the secrets its workflow read were
# still unset; the step sat in prose between the summary and the check table.
class PublicationStepsBesidesMergingTest < Minitest::Test
  STEP = { 'when' => 'before merge', 'step' => 'Set DOCS_DISPATCH_APP_ID and DOCS_DISPATCH_APP_KEY',
           'who' => 'Maintainer', 'where' => 'shakacode/shaka Actions secrets',
           'verify' => '`gh secret list` shows both names' }.freeze

  AFTER_STEP = STEP.merge('when' => 'after merge', 'step' => 'Run the docs dispatch',
                          'where' => 'Docs site', 'verify' => 'The site shows the merged docs').freeze

  def render(**changes)
    Shaka::Publication.description(
      { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.',
        'walkthrough' => PublicationRegressionTest::WALKTHROUGH, 'deployment' => 'none',
        'steps_besides_merging' => 'none', 'table' => PublicationRegressionTest::TABLE,
        'provenance' => PUBLIC_PROVENANCE, 'usage' => PublicationRegressionTest::USAGE_OBJECT,
        'details' => [] }.merge(changes)
    )
  end

  def test_steps_render_as_a_table_after_the_decisions_and_walkthrough_link
    rendered = render('steps_besides_merging' => [STEP, AFTER_STEP], 'decisions' => ['Which base?'])
    table = "| When | Step | Who | Where | How to verify |\n| --- | --- | --- | --- | --- |\n" \
            '| before merge | Set DOCS_DISPATCH_APP_ID and DOCS_DISPATCH_APP_KEY | Maintainer | ' \
            "shakacode/shaka Actions secrets | `gh secret list` shows both names |\n" \
            "| after merge | Run the docs dispatch | Maintainer | Docs site | The site shows the merged docs |\n"
    steps = rendered.index("<!-- shaka:steps-besides-merging -->\n## Before and after merge\n\n#{table}")

    refute_nil steps
    assert_operator rendered.index('## Decisions to make'), :<, rendered.index('[Code Walkthrough](')
    assert_operator rendered.index('[Code Walkthrough]('), :<, steps
  end

  def test_an_escaped_pipe_in_a_cell_cannot_split_the_row
    rendered = render('steps_besides_merging' => [STEP.merge('step' => 'Set a\\|b')])
    assert_includes rendered, '| before merge | Set a\\\\\\|b | Maintainer |'
  end

  def test_none_omits_the_section_after_the_agent_checked
    refute_includes render, 'Before and after merge'
  end

  def test_a_missing_answer_is_refused_so_the_check_cannot_be_skipped
    error = assert_raises(Shaka::Error) { render('steps_besides_merging' => nil) }
    assert_includes error.message, 'steps_besides_merging'
  end

  def test_an_empty_list_is_refused_in_favor_of_none
    error = assert_raises(Shaka::Error) { render('steps_besides_merging' => []) }
    assert_includes error.message, 'none'
  end

  def test_a_step_without_a_timing_the_reader_can_act_on_is_refused
    error = assert_raises(Shaka::Error) { render('steps_besides_merging' => [STEP.merge('when' => 'soon')]) }
    assert_includes error.message, 'before merge'
  end

  def test_a_step_missing_a_field_is_refused
    error = assert_raises(Shaka::Error) { render('steps_besides_merging' => [STEP.except('verify')]) }
    assert_includes error.message, 'verify'
  end

  def test_a_hand_written_section_is_refused
    ['Before and after merge', 'Steps besides merging'].each do |heading|
      error = assert_raises(Shaka::Error) do
        render('sections' => [{ 'heading' => heading, 'body' => '- Set a secret.' }])
      end
      assert_includes error.message, 'steps_besides_merging'
    end
  end
end
