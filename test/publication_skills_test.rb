# frozen_string_literal: true

require_relative 'publication_test'

class PublicationSkillsTest < Minitest::Test
  def render(**changes)
    Shaka::Publication.description(
      { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.',
        'walkthrough' => PublicationRegressionTest::WALKTHROUGH, 'deployment' => 'none',
        'steps_besides_merging' => 'none', 'table' => PublicationRegressionTest::TABLE,
        'provenance' => PUBLIC_PROVENANCE, 'usage' => PublicationRegressionTest::USAGE_OBJECT,
        'details' => [] }.merge(changes)
    )
  end

  def skill(**changes)
    { 'name' => 'pstack-investigate', 'source' => 'PStack', 'revision' => 'UNKNOWN',
      'phase' => 'implementation', 'contribution' => 'Investigated the failing parser',
      'evidence' => 'agent-reported', 'corroboration' => nil }.merge(changes)
  end

  def test_skill_reports_render_in_one_collapsed_section_with_distinct_evidence
    records = [skill, skill('name' => 'to-spec', 'source' => 'AI Hero', 'phase' => 'planning',
                            'evidence' => 'corroborated', 'corroboration' => 'Native invocation event')]
    rendered = render('skills_used' => records)

    assert_equal 1, rendered.scan('<summary>Skills used</summary>').size
    assert_includes rendered, '| pstack-investigate | PStack | UNKNOWN | implementation |'
    assert_includes rendered, '| Agent-reported | — |'
    assert_includes rendered, '| Corroborated | Native invocation event |'
    assert_includes rendered, 'Shaka does not check that record'
    assert_includes rendered, 'Completeness is not verified'
    refute_includes rendered, '<details open'
  end

  def test_missing_or_empty_reports_disclose_unknown_coverage
    [nil, []].each do |records|
      rendered = render('skills_used' => records)
      assert_includes rendered, 'No skill use recorded; coverage is UNKNOWN.'
    end
  end

  def test_shaka_rows_are_omitted_because_provenance_names_the_workflow_version
    shaka = skill('name' => 'shaka', 'source' => 'ShakaCode/shaka', 'revision' => 'c6a2512')
    rendered = render('skills_used' => [shaka, skill, shaka.merge('name' => 'Shaka', 'phase' => 'review')])

    assert_includes rendered, '| pstack-investigate |'
    refute_match(/\| shaka \|/i, rendered)
  end

  def test_shaka_only_reports_say_no_other_skill_was_reported
    rendered = render('skills_used' => [skill('name' => 'shaka', 'source' => 'ShakaCode/shaka')])

    assert_includes rendered, 'No skills besides Shaka were reported.'
    refute_includes rendered, 'coverage is UNKNOWN'
    refute_includes rendered, '| Skill |'
  end

  def test_a_same_named_skill_from_another_source_stays_listed
    rendered = render('skills_used' => [skill('name' => 'shaka', 'source' => 'Example/fork')])

    assert_includes rendered, '| shaka | Example/fork |'
  end

  def test_omitted_shaka_rows_are_still_validated
    assert_raises(Shaka::Error) { render('skills_used' => [skill('name' => 'shaka', 'evidence' => 'verified')]) }
  end

  def test_corroboration_is_required_without_promoting_an_agent_report
    error = assert_raises(Shaka::Error) { render('skills_used' => [skill('evidence' => 'corroborated')]) }
    assert_includes error.message, 'corroboration'
    error = assert_raises(Shaka::Error) do
      render('skills_used' => [skill('corroboration' => 'A skill was mentioned')])
    end
    assert_includes error.message, 'agent-reported'
  end

  def test_bad_records_are_rejected_before_publication
    [false, {}, [nil], [skill.except('name')], [skill.merge(1 => 'bad')], [skill('transcript' => 'private')],
     [skill('evidence' => 'verified')], [skill('phase' => "review\nintegration")],
     [skill('contribution' => ' ')]].each do |records|
      assert_raises(Shaka::Error) { render('skills_used' => records) }
    end
  end

  def test_cells_cannot_break_the_table_or_close_the_disclosure
    rendered = render('skills_used' => [skill('name' => 'a|b', 'contribution' => '</details><script>bad</script>')])

    assert_includes rendered, 'a\\|b'
    assert_includes rendered, '&lt;/details&gt;&lt;script&gt;bad&lt;/script&gt;'
    refute_includes rendered, '<script>'
  end

  def test_duplicate_reports_collapse_but_different_phases_remain
    rendered = render('skills_used' => [skill, skill, skill('phase' => 'review')])
    assert_equal 2, rendered.scan('| pstack-investigate |').size
  end

  def test_free_form_skill_details_are_refused
    error = assert_raises(Shaka::Error) do
      render('details' => [{ 'summary' => ' skills USED ', 'body' => 'Everything was verified.' }])
    end
    assert_includes error.message, 'skills_used'
  end
end
