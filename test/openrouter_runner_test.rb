# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'openrouter_fixture'
require 'shaka/local_review'

class OpenrouterRunnerTest < Minitest::Test
  include OpenrouterFixture

  def test_runs_the_review_command_and_records_publishable_diff_only_evidence
    with_review_repository do |root, base, head|
      response = completion(head)
      with_request(capturing_request(response)) do
        with_run(root, base, head) do |result, status|
          assert_completed(result, status)
          assert_publishable(result)
        end
      end
    end
  end

  def test_wrong_head_attestation_fails_but_keeps_charged_usage
    with_review_repository do |root, base, head|
      with_request(->(*) { completion }) do
        with_run(root, base, head) do |result, status|
          assert_equal 1, status
          assert_equal 'report_validation', result.fetch('failure_stage')
          assert File.size?(result.fetch('usage'))
        end
      end
    end
  end

  def test_unsupported_model_or_effort_fails_before_a_request
    [{ model: 'deepseek-flash' }, { model: nil }, { effort: 'medium' }].each do |choices|
      with_review_repository do |root, base, head|
        with_request(->(*) { flunk 'unsupported settings must not reach the API' }) do
          with_run(root, base, head, **choices) do |result, status|
            assert_setup_failure(result, status)
          end
        end
      end
    end
  end

  private

  def capturing_request(response)
    lambda do |prompt, **|
      @prompt = prompt
      response
    end
  end

  def assert_completed(result, status)
    assert_equal 0, status
    assert_equal 'completed', result.fetch('status')
    assert_includes result.fetch('coverage'), 'Supplied diff only'
    assert_includes @prompt, 'puts :after'
    assert_includes @prompt, 'API has no filesystem or tools'
  end

  def assert_setup_failure(result, status)
    assert_equal 1, status
    assert_equal 'setup_failure', result.fetch('failure_stage')
    refute result.fetch('attempted')
  end

  def with_run(root, base, head, **choices)
    args = { root:, base:, head:, reviewer: 'deepseek/openrouter', model: MODEL, effort: 'high' }.merge(choices)
    command = ['run', *args.compact.flat_map { |key, value| ["--#{key}", value] }]
    with_key do
      output, error = capture_io { @status = Shaka::LocalReview.run(command) }
      assert_empty error
      result = JSON.parse(output)
      yield result, @status
    ensure
      %w[report usage].each { |key| FileUtils.rm_f(result[key]) if result && result[key] }
    end
  end

  def assert_publishable(result)
    round = result.merge('effort' => 'high')
    body = Shaka::LocalReviewCommitComment.new({ 'rounds' => [round] }, head: result.fetch('head'),
                                                                        subject: ->(*) { 'fixture' }).render
    assert_includes body, MODEL
    assert_includes body, 'Supplied diff only'
    assert_equal "REVIEWED #{result.fetch('head')} BY deepseek/openrouter EFFORT high FINDINGS 0", body.lines.last.strip
  end
end
