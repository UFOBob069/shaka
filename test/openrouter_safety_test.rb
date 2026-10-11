# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'openrouter_fixture'
require 'shaka/usage/command'
require 'shaka/doctor/cli_inventory'

class OpenrouterSafetyTest < Minitest::Test
  include OpenrouterFixture

  def test_report_write_failure_keeps_usage_and_names_local_evidence_failure
    with_adapter do |cli, options, _report|
      with_request(->(*) { completion }) do
        replacing_method(File, :write, ->(*) { raise Errno::ENOSPC }) do
          result = cli.run('diff')
          assert_equal 'evidence_write', result.fetch('failure_stage')
          assert_includes result.fetch('reason'), 'response received'
          assert File.size?(options.fetch(:usage))
        end
      end
    end
  end

  def test_invalid_prompt_bytes_fail_before_transport
    with_adapter do |cli, _options, _report|
      result = cli.run("\xff".b.force_encoding('UTF-8'))
      assert_equal 'setup_failure', result.fetch('failure_stage')
      refute result.fetch('attempted')
    end
  end

  def test_invalid_key_bytes_return_a_failure
    key = "\xff".b.force_encoding('UTF-8')
    with_adapter do |cli, _options, _report|
      with_key(key) do
        result = cli.run('diff')
        assert_equal 'credentials_invalid', result.fetch('failure_stage')
        refute result.fetch('attempted')
      end
    end
  end

  def test_invalid_key_bytes_do_not_break_inventory
    key = "\xff".b.force_encoding('UTF-8')
    system = Struct.new(:executable).new(->(*) {})
    inventory = Shaka::Doctor::CliInventory.new(root: Dir.tmpdir, environment: { 'OPENROUTER_API_KEY' => key }, system:)
    assert_instance_of Array, inventory.call(nil)
  end

  def test_multiline_key_fails_before_transport_without_disclosing_it
    with_adapter do |cli, _options, _report|
      with_key("fixture-private-key\nsecond-line") do
        with_request(->(*) { flunk 'invalid credentials must not reach the API' }) do
          result = cli.run('diff')
          assert_equal 'credentials_invalid', result.fetch('failure_stage')
          refute result.fetch('attempted')
          refute_includes JSON.generate(result), 'fixture-private-key'
        end
      end
    end
  end

  def test_transport_rejects_multiline_header_without_disclosing_the_key
    with_key("fixture-private-key\nsecond-line") do
      error = assert_raises(Shaka::Error) do
        Shaka::OpenrouterReview.request('diff', model: MODEL, effort: 'high', timeout: 1)
      end
      refute_includes error.message, 'fixture-private-key'
    end
  end

  def test_malformed_content_length_returns_a_sanitized_transport_failure
    response = Net::HTTPOK.new('1.1', '200', 'OK')
    response['Content-Length'] = 'private-header-detail'
    with_adapter do |cli, _options, _report|
      with_request(->(*) { response.content_length }) do
        result = cli.run('diff')
        assert_equal 'cli_failure', result.fetch('failure_stage')
        assert_includes result.fetch('reason'), 'network/TLS request failed'
        refute_includes JSON.generate(result), 'private-header-detail'
      end
    end
  end

  def test_metadata_tokens_retain_slugs_and_reject_autolink_urls
    assert_equal MODEL, Shaka::OpenrouterReview.token(MODEL)
    %w[https://evil.example/x www.evil.example/x WWW.evil.example ftp://evil.example/x].each do |value|
      assert_nil Shaka::OpenrouterReview.token(value)
      assert_equal 'UNKNOWN', Shaka::Usage.allocate.send(:safe, value)
      assert_equal 'UNKNOWN', Shaka::CostEstimate.new([]).send(:safe, value)
    end
  end
end
