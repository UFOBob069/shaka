# frozen_string_literal: true

require_relative 'publication_test'

# https://github.com/shakacode/shaka/issues/606: code spans ignore backslash escapes,
# so doubling every backslash in a cell turned `\d+` into a visible `\\d+`.
class PublicationTableCellTest < Minitest::Test
  def test_a_code_span_in_a_cell_keeps_its_backslashes_and_escapes_its_pipes
    rows = [['`\\d+` regex', '`a|b`'], ['`a\\|b`', '`` x`\\d`|y `` and a\\b|c']]
    rendered = Shaka::Publication.description(
      { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.',
        'walkthrough' => PublicationRegressionTest::WALKTHROUGH, 'deployment' => 'none',
        'steps_besides_merging' => 'none', 'intent' => INTENT, 'verification' => VERIFICATION,
        'table' => { 'columns' => %w[A B], 'rows' => rows }, 'provenance' => PUBLIC_PROVENANCE,
        'usage' => PublicationRegressionTest::USAGE_OBJECT }
    )
    assert_includes rendered, '| `\\d+` regex | `a\\|b` |'
    assert_includes rendered, '| `a\\\\|b` | `` x`\\d`\\|y `` and a\\\\b\\|c |'
  end

  def test_an_unclosed_backtick_leaves_the_rest_of_the_cell_as_text
    assert_equal '`a\\\\b\\|c', Shaka::PublicationText.table_cell('`a\\b|c')
    assert_equal '``a\\\\b` \\|', Shaka::PublicationText.table_cell('``a\\b` |')
  end
end
