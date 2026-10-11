# frozen_string_literal: true

require_relative 'post_implementation_summary_test'

class PostImplementationCompactTest < Minitest::Test
  include PostImplementationSummaryFixture

  def test_routine_report_keeps_the_decision_visible_without_repeating_the_conclusion
    visible = routine_report.split('<details>', 2).first

    assert_includes visible, 'Recommendation: **Merge if CI passes**'
    refute_includes visible, 'after required checks and approvals'
    assert_includes visible, 'The label is clearer and older notes remain readable.'
    assert_includes visible, 'Complete the required approval.'
    assert_includes visible, 'a' * 40
    refute_includes visible, 'Conclusion:'
  end

  def test_supporting_analysis_and_usage_remain_available_in_closed_details
    visible, details = routine_report.split('<details>', 2)
    ['Compatibility remains intact.', 'No new dependencies.',
     'Documentation alone leaves the ambiguous label.', 'Ruby verified report shape'].each do |evidence|
      refute_includes visible, evidence
      assert_includes details, evidence
    end
    assert_includes details, 'Native usage: UNKNOWN'
    refute_includes details, '<details open'
  end

  def test_substantive_concerns_stay_visible_for_every_conclusion
    Shaka::PostImplementationReport::CONCLUSIONS.each do |conclusion|
      with_result do |result, path|
        change_report(result, 'conclusion' => conclusion, 'summary' => 'The approach needs attention.',
                              'concerns' => ['Existing notes cannot be recovered.'])
        visible, details = rendered(result, path).split('<details>', 2)

        assert_includes visible, 'Existing notes cannot be recovered.'
        refute_includes visible, 'Recommendation: **Merge if CI passes**'
        assert_includes details, "Conclusion: **#{conclusion}**"
      end
    end
  end

  def test_failed_and_opted_out_reports_keep_the_reason_visible
    %w[not_completed opted_out].each do |status|
      with_result do |result, path|
        result['status'] = status
        result['reason'] = 'The provider could not complete this review.'
        visible = rendered(result, path).split('<details>', 2).first

        assert_includes visible, 'The provider could not complete this review.'
        assert_includes visible, 'a' * 40
        refute_includes visible, 'Recommendation: **Merge if CI passes**'
      end
    end
  end

  def test_legacy_report_shows_its_first_reason_once_and_preserves_the_rest
    with_result do |result, path|
      change_report(result, 'reasons' => ['Useful change', 'Compatible with older notes'])
      body = rendered(result, path)
      visible, details = body.split('<details>', 2)

      assert_includes visible, 'Useful change'
      assert_equal 1, body.scan('Useful change').size
      refute_includes visible, 'Compatible with older notes'
      assert_includes details, 'Compatible with older notes'
    end
  end

  private

  def routine_report
    with_result do |result, path|
      change_report(result, 'summary' => 'The label is clearer and older notes remain readable.',
                            'next_action' => 'Complete the required approval.',
                            'reasons' => ['Compatibility remains intact.', 'No new dependencies.'],
                            'alternative' => 'Documentation alone leaves the ambiguous label.')
      rendered(result, path)
    end
  end
end
