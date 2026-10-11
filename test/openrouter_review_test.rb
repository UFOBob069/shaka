# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'openrouter_fixture'
require 'shaka/local_review'
require 'shaka/local_review/runner'
require 'shaka/local_review/comment'
require 'shaka/usage/command'

class OpenrouterReviewTest < Minitest::Test
  include OpenrouterFixture

  def test_review_adapter_retains_report_model_and_aggregate_usage
    assert_includes Shaka::ReviewerSelection::SUPPORTED_REVIEWERS, 'deepseek/openrouter'
    with_adapter do |cli, options, report|
      response = completion
      with_request(->(*) { response }) do
        assert_nil cli.run('review this diff')
      end
      assert_includes File.read(report), "REVIEWED #{HEAD} BY deepseek/openrouter"
      assert_equal MODEL, options.fetch(:observed_model)
      assert_metadata(options)
    end
  end

  def test_missing_key_does_not_attempt_a_request
    with_adapter do |cli, _options, _report|
      with_key(nil) do
        with_request(->(*) { flunk 'must not send a request' }) do
          result = cli.run('diff')
          refute result.fetch('attempted')
          assert_equal 'credentials_missing', result.fetch('failure_stage')
        end
      end
    end
  end

  def test_malformed_empty_and_truncated_results_do_not_complete
    [[], {}, { 'choices' => [{}] }, completion.merge('choices' => [{ 'finish_reason' => 'length' }])].each do |response|
      with_adapter do |cli, _options, report|
        with_request(->(*) { response }) do
          result = cli.run('diff')
          assert_equal 'not_completed', result.fetch('status')
          assert_equal 'report_validation', result.fetch('failure_stage')
          refute File.exist?(report) && File.size?(report)
        end
      end
    end
  end

  def test_api_errors_with_http_success_do_not_complete_or_disclose_messages
    with_adapter do |cli, _options, _report|
      with_request(->(*) { completion.merge('error' => { 'message' => 'private-account-detail' }) }) do
        result = cli.run('diff')
        assert_equal 'cli_failure', result.fetch('failure_stage')
        refute_includes JSON.generate(result), 'private-account-detail'
      end
    end
  end

  private

  def assert_metadata(options)
    metadata = JSON.parse(File.read(options.fetch(:usage)))
    refute metadata.key?('choices')
    assert_in_delta 0.0024, metadata.dig('usage', 'cost')
  end
end
