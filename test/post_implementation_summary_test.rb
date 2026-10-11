# frozen_string_literal: true

require_relative 'post_implementation_publication_test'

module PostImplementationSummaryFixture
  include PostImplementationPublicationFixture

  private

  def rendered(result, path)
    github, status = publish(result, path)
    assert_equal 0, status
    github.bodies.first.first
  end

  def change_report(result, changes)
    report = JSON.parse(File.read(result.fetch('report'))).merge(changes)
    File.write(result.fetch('report'), JSON.generate(report))
  end

  def claude_usage(result, path, **changes)
    attach_private_usage(result, path)
    usage = JSON.parse(File.read(result.fetch('usage'))).merge(changes.transform_keys(&:to_s))
    File.write(result.fetch('usage'), JSON.generate(usage))
  end

  def codex_usage(result, path)
    records = [
      { type: 'session_meta', payload: { model_provider: 'openai' } },
      { type: 'turn_context', payload: { turn_id: 'turn', model: 'gpt-6.1-sol', effort: 'medium' } },
      { type: 'token_usage_record', payload: { response_id: 'response', turn_id: 'turn', usage: {} } }
    ]
    result['usage'] = File.join(File.dirname(path), 'usage.jsonl')
    File.write(result.fetch('usage'), records.map { |record| JSON.generate(record) }.join("\n"))
  end
end

class PostImplementationModelPublicationTest < Minitest::Test
  include PostImplementationSummaryFixture

  def test_configured_codex_model_is_visible_without_claiming_a_served_model
    with_result do |result, path|
      codex_usage(result, path)
      identity = rendered(result, path)
      assert_includes identity, 'configured model: gpt-6.1-sol'
      heading = /\A🤖 Codex · OpenAI · gpt-6\.1-sol \(configured\) · medium\n\n# Post-implementation validation\n\n/
      assert_match heading, identity
      assert_operator identity.index('observed model:'), :>, identity.index('<details>')
      assert_includes identity, 'observed model: UNKNOWN'
      assert_includes identity, 'recorded effort: medium'
    end
  end

  def test_missing_blank_and_unknown_observations_keep_requested_model_visible
    [nil, '', 'UNKNOWN', 'unknown'].each do |model|
      with_result do |result, path|
        claude_usage(result, path, model:)
        result['requested_model'] = 'chosen-model'
        identity = rendered(result, path)
        assert_includes identity, 'observed model: UNKNOWN'
        assert_includes identity, 'requested model: chosen-model'
      end
    end
  end

  def test_observed_model_and_effort_do_not_hide_different_requested_settings
    with_result do |result, path|
      claude_usage(result, path, effort: 'high')
      result['requested_model'] = 'chosen-model'
      identity = rendered(result, path)
      assert_includes identity, 'observed model: observed-model; requested model: chosen-model'
      assert_includes identity, 'recorded effort: high; requested effort: medium'
    end
  end

  def test_requested_only_settings_and_legacy_report_remain_publishable
    with_result do |result, path|
      result['requested_model'] = 'chosen-model'
      body = rendered(result, path)
      assert_includes body, 'observed model: UNKNOWN; requested model: chosen-model'
      assert_includes body, 'Recommendation: **Merge if CI passes**'
      assert_includes body, '**Next action (task owner):** Complete technical validation and required approvals.'
      assert_equal 1, body.scan('Useful change').size
    end
  end
end

class PostImplementationSummaryTest < Minitest::Test
  include PostImplementationSummaryFixture

  def test_summary_and_owner_action_precede_analysis_and_usage
    with_result do |result, path|
      change_report(result, 'conclusion' => 'Simplify/reframe', 'summary' => 'Keep the safeguard; remove unused scans.',
                            'next_action' => 'Revise this PR, then revalidate.', 'reasons' => ['Maintenance evidence'])
      body = rendered(result, path)
      assert_includes body, 'Recommendation: **Revise before merging.**'
      assert_includes body, '**Next action (task owner):** Revise the approach, then revalidate and review.'
      assert_operator body.index('Keep the safeguard'), :<, body.index('Maintenance evidence')
      assert_operator body.index('Next action (task owner)'), :<, body.index('Maintenance evidence')
    end
  end

  def test_proceed_with_concerns_never_recommends_merging
    with_result do |result, path|
      change_report(result, 'concerns' => ['Audience mismatch remains'])
      body = rendered(result, path)
      assert_includes body, 'Recommendation: **Resolve concerns before merging.**'
      assert_includes body, 'Audience mismatch remains'
    end
  end

  def test_optional_summary_fields_reject_malformed_values_without_publishing
    combinations = %w[summary next_action].product([nil, '', [], 42])
    combinations.each do |key, value|
      with_result do |result, path|
        change_report(result, key => value)
        github, status = publish(result, path)
        assert_equal 1, status
        assert_empty github.bodies
      end
    end
  end

  def test_reviewer_action_cannot_override_a_blocking_result
    [{ 'conclusion' => 'Proceed', 'concerns' => ['Audience mismatch remains'] },
     { 'conclusion' => 'Simplify/reframe' }, { 'conclusion' => 'Do not merge' }].each do |blocker|
      with_result do |result, path|
        change_report(result, blocker.merge('next_action' => 'Merge now.'))
        refute_includes rendered(result, path), '**Next action (task owner):** Merge now.'
      end
    end
  end

  def test_unblocked_review_keeps_the_specific_owner_action
    with_result do |result, path|
      change_report(result, 'next_action' => 'Complete the required approval.')
      assert_includes rendered(result, path), '**Next action (task owner):** Complete the required approval.'
    end
  end

  def test_rejected_review_does_not_claim_readiness
    with_result do |result, path|
      change_report(result, 'conclusion' => 'Do not merge')
      assert_includes rendered(result, path), 'Do not merge; decide whether to close or replace.'
    end
  end

  def test_failed_and_opted_out_reviews_do_not_claim_readiness
    { 'not_completed' => 'Review not completed; readiness remains blocked.',
      'opted_out' => 'Checkpoint opted out; no product review completed.' }.each do |status, recommendation|
      with_result do |result, path|
        result['status'] = status
        result['reason'] = 'Recorded reason'
        result.delete('report')
        body = rendered(result, path)
        assert_includes body, recommendation
      end
    end
  end
end
