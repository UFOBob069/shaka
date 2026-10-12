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
    assert_includes body, 'Evaluation: **Proceed**'
    assert_includes body, "Recommended next action: **#{result['disposition']['recommendation']}**"
    assert_includes body, result['disposition']['reason']
    assert_includes body, result['disposition']['next_action']
    assert_includes body, 'Required checks, reviews, and merge authority still apply.'
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
     disposition('Merge').merge('next_action' => ' ')].each do |invalid|
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
