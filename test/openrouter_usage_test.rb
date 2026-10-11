# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'openrouter_fixture'
require 'shaka/usage/command'
require 'shaka/publication/usage_details'

class OpenrouterUsageTest < Minitest::Test
  include OpenrouterFixture

  def test_usage_command_prices_the_recorded_charge_and_keeps_slash_model_names
    with_metadata do |file|
      record = usage_report(file).fetch('record')
      column = record.fetch('columns').first
      assert_api_column(column)
      assert_includes record.fetch('note'), 'OpenRouter recorded charged USD'
    end
  end

  def test_absent_usage_and_cost_never_become_zero
    [{}, { 'prompt_tokens' => 100 }, { 'cost' => -1 }, { 'cost' => '0.0024' }].each do |usage|
      with_metadata(usage:) do |file|
        column = usage_report(file).fetch('columns').first
        assert_equal 'UNKNOWN', column.fetch('usd')
        assert_equal 'UNKNOWN', column.fetch('output')
      end
    end
  end

  def test_invalid_metadata_bytes_are_unreadable
    Tempfile.create(['openrouter-invalid-', '.json']) do |file|
      file.binmode.write("{\"shaka_openrouter\":1,\"id\":\"r\",\"model\":\"\xff\"}".b)
      file.close
      source = Shaka::OpenrouterUsage.new([file.path], [], all_turns: true)
      assert_empty source.responses
      refute_empty source.gaps
    end
  end

  def test_an_absent_observed_model_is_not_filled_from_the_request
    with_metadata(model: nil) do |file|
      column = usage_report(file).fetch('columns').first
      assert_equal MODEL, column.fetch('model')
      assert_equal 'UNKNOWN', column.fetch('routed')
    end
  end

  def test_copied_response_files_are_counted_once
    with_metadata do |file|
      source = Shaka::OpenrouterUsage.new([file, file], [], all_turns: true)
      assert_equal 1, source.responses.size
      assert_equal 100, source.responses.values.first.dig('usage', 'input_tokens')
    end
  end

  def test_metadata_can_render_in_the_existing_pr_usage_table
    with_metadata do |file|
      data = usage_report(file)
      rendered = Shaka::UsageDetails.new('note' => data.fetch('note'),
                                         'records' => [data.fetch('record')]).detail.fetch('body')
      assert_includes rendered, 'OpenRouter'
      assert_includes rendered, 'deepseek/'
      assert_includes rendered, 'account charge'
    end
  end

  def test_pi_deepseek_nominal_cost_is_not_described_as_an_openrouter_charge
    record = { 'configuration' => ['deepseek', MODEL, MODEL, 'high'], 'usage' => { 'native_cost_usd' => 0.0024 } }
    report = Shaka::CostEstimate.new([record]).report
    assert_includes report, 'Pi recorded native nominal USD'
    refute_includes report, 'OpenRouter recorded charged USD'
  end

  private

  def assert_api_column(column)
    expected = { 'model' => MODEL, 'routed' => MODEL, 'usd' => '$0.002400', 'credits' => 'UNKNOWN',
                 'input' => '100', 'cached_input' => '40', 'output' => '20',
                 'reasoning_output' => '5', 'cache_writes' => 'UNKNOWN' }
    assert_equal expected, column.slice(*expected.keys)
  end

  def with_metadata(**changes)
    data = completion.slice('id', 'model', 'created', 'usage').merge(
      'shaka_openrouter' => 1, 'requested_model' => MODEL, 'effort' => 'high'
    ).merge(changes.transform_keys(&:to_s))
    Tempfile.create(['openrouter-usage-', '.json']) do |file|
      file.write(JSON.generate(data))
      file.close
      yield file.path
    end
  end

  def usage_report(file)
    args = ['--host', 'openrouter', '--file', file, '--all-turns', '--commit', HEAD,
            '--contribution', 'review', '--format', 'json']
    output, error = capture_io { @usage_status = Shaka::Usage.run(args) }
    assert_equal 0, @usage_status, error
    JSON.parse(output)
  end
end
