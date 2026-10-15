# frozen_string_literal: true

require_relative 'post_implementation_publication_test'

module PostImplementationDispositionFixture
  include PostImplementationPublicationFixture

  def disposition(recommendation)
    { 'head' => 'a' * 40, 'recommendation' => recommendation,
      'reason' => 'The implementation works, but the completed approach costs too much.',
      'next_action' => 'Propose the smaller alternative to the maintainer.' }
  end

  def assert_owner_decision(github, result)
    body = github.bodies.first.first
    assert_includes body, '**Reviewer verdict:** Proceed'
    assert_includes body, "## Recommendation: #{result['disposition']['recommendation']}"
    assert_includes body, result['disposition']['reason']
    assert_includes body, "**Next:** #{result['disposition']['next_action']}"
    assert_includes body, 'Required checks, reviews, and merge authority still apply.'
  end

  def accepted(*concerns)
    concerns.map { |concern| { 'concern' => concern, 'decision' => 'Justin accepted this in chat on 2026-10-11.' } }
  end

  def verification(result, conclusion, concerns)
    report = JSON.parse(File.read(result['report'])).merge('conclusion' => conclusion, 'concerns' => concerns)
    File.write(result['report'], JSON.generate(report))
  end
end

class PostImplementationDispositionTest < Minitest::Test
  include PostImplementationDispositionFixture

  def test_owner_can_reconsider_or_reject_a_successfully_verified_implementation
    ['Reconsider approach', 'Do not merge', 'Revise before merge'].each do |recommendation|
      with_result do |result, path|
        result['disposition'] = disposition(recommendation)
        github, status = publish(result, path)
        assert_equal 0, status
        assert_owner_decision(github, result)
        assert_raises(Shaka::Error) { Shaka::PostImplementationEvidence.new(github).call('a' * 40) }
        assert_equal recommendation, Shaka::PostImplementationEvidence.new(github).recommendation('a' * 40)
      end
    end
  end

  def test_merge_disposition_keeps_the_product_checkpoint_separate_from_authority
    with_result do |result, path|
      result['disposition'] = disposition('Merge').merge('reason' => 'The verified fix meets the original request.',
                                                         'next_action' => 'Finish required checks and Ask handoff.')
      github, status = publish(result, path)
      assert_equal 0, status
      assert_owner_decision(github, result)
      assert_equal 'ready', Shaka::PostImplementationEvidence.new(github).call('a' * 40)['basis']
      assert_equal 'Merge', Shaka::PostImplementationEvidence.new(github).recommendation('a' * 40)
    end
  end
end

class PostImplementationDispositionValidationTest < Minitest::Test
  include PostImplementationDispositionFixture

  def test_owner_cannot_use_merge_to_override_a_blocked_verification
    [['Proceed', ['Acceptance is unresolved.']], ['Simplify/reframe', []],
     ['Do not merge', []]].each do |conclusion, concerns|
      with_result do |result, path|
        verification(result, conclusion, concerns)
        result['disposition'] = disposition('Merge')
        github, status = publish(result, path)
        assert_equal 1, status
        assert_empty github.bodies
      end
    end
  end

  def test_disposition_for_an_older_head_cannot_be_published
    with_result do |result, path|
      result['disposition'] = disposition('Merge').merge('head' => 'b' * 40)
      github, status = publish(result, path)
      assert_equal 1, status
      assert_empty github.bodies
    end
  end

  def test_invalid_dispositions_cannot_publish_a_ready_attestation
    [nil, [], disposition('Ship'), disposition('Merge').except('reason'),
     disposition('Merge').except('next_action'), disposition('Merge').merge('next_action' => ' ')].each do |invalid|
      with_result do |result, path|
        result['disposition'] = invalid
        github, status = publish(result, path)
        assert_equal 1, status
        assert_empty github.bodies
      end
    end
  end

  def test_failed_or_opted_out_verification_cannot_have_a_completed_disposition
    %w[not_completed opted_out].each do |state|
      with_result do |result, path|
        result.merge!('status' => state, 'reason' => 'No product verification completed.',
                      'disposition' => disposition('Merge'))
        github, status = publish(result, path)
        assert_equal 1, status
        assert_empty github.bodies
      end
    end
  end
end

class PostImplementationAcceptedConcernTest < Minitest::Test
  include PostImplementationDispositionFixture

  def merge_with(result, conclusion, concerns, acceptance)
    verification(result, conclusion, concerns)
    result['disposition'] = disposition('Merge').merge('accepted_concerns' => acceptance)
  end

  def test_merge_is_ready_when_the_maintainer_accepted_every_listed_concern
    with_result do |result, path|
      merge_with(result, 'Proceed', ['Frequency is unknown.'], accepted('Frequency is unknown.'))
      github, status = publish(result, path)
      body = github.bodies.first.first

      assert_equal 0, status
      assert_includes body, '**Unresolved concerns:** None.'
      assert_includes body, '- Frequency is unknown. — Decision: Justin accepted this in chat on 2026-10-11.'
      assert_includes body, 'not who made it'
      assert_equal 'ready', Shaka::PostImplementationEvidence.new(github).call('a' * 40)['basis']
    end
  end

  def assert_refused(conclusion, concerns, acceptance)
    with_result do |result, path|
      merge_with(result, conclusion, concerns, acceptance)
      github, status = publish(result, path)
      assert_equal 1, status, acceptance.inspect
      assert_empty github.bodies
    end
  end

  def test_merge_stays_refused_while_any_concern_lacks_a_decision
    first, last = concerns = ['Frequency is unknown.', 'The flag has no test.']
    [accepted(first), [], [{ 'concern' => first, 'decision' => ' ' }, *accepted(last)],
     accepted(*concerns, 'A concern the report never listed.'), accepted(first, *concerns),
     'all', [first]].each { |acceptance| assert_refused('Proceed', concerns, acceptance) }
  end

  def test_a_decision_cannot_hide_or_imitate_the_published_comment
    concern = 'Frequency is unknown.'
    ["Fine.\n\n**Unresolved concerns:**", 'Fine. <!--', 'Fine. ```'].each do |decision|
      assert_refused('Proceed', [concern], [{ 'concern' => concern, 'decision' => decision }])
    end
  end

  def test_acceptance_cannot_override_a_blocking_conclusion
    ['Simplify/reframe', 'Do not merge'].each do |conclusion|
      assert_refused(conclusion, ['Too costly.'], accepted('Too costly.'))
    end
  end

  def test_other_recommendations_stay_blocked_and_show_the_remaining_concern
    with_result do |result, path|
      merge_with(result, 'Proceed', ['Frequency is unknown.', 'The flag has no test.'],
                 accepted('Frequency is unknown.'))
      result['disposition']['recommendation'] = 'Revise before merge'
      github, = publish(result, path)
      body = github.bodies.first.first

      assert_includes body, "**Unresolved concerns:**\n\n- The flag has no test."
      assert_includes body, '- Frequency is unknown. — Decision:'
      assert_raises(Shaka::Error) { Shaka::PostImplementationEvidence.new(github).call('a' * 40) }
    end
  end
end
