# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'openrouter_fixture'

class OpenrouterRequestTest < Minitest::Test
  include OpenrouterFixture

  def test_sends_one_fixed_model_request_without_tools_or_fallback
    with_http_response do
      assert_equal 'Bearer fixture-only', @request['Authorization']
      body = JSON.parse(@request.body)
      assert_equal MODEL, body.fetch('model')
      assert_equal 65_536, body.fetch('max_tokens')
      assert_equal({ 'effort' => 'high' }, body.fetch('reasoning'))
      assert_equal 'diff', body.dig('messages', 0, 'content')
      assert_empty body.keys & %w[models tools]
    end
  end

  def test_transport_has_timeouts_and_disables_automatic_retries
    with_http_response do
      assert_equal ['openrouter.ai', 443], @endpoint
      assert_equal 0, @http_options.fetch(:max_retries)
      assert_equal 1, @http_options.fetch(:open_timeout)
      assert_equal 1, @http_options.fetch(:read_timeout)
      assert_equal 1, @http_options.fetch(:write_timeout)
      assert_true @http_options.fetch(:use_ssl)
    end
  end

  def test_http_errors_return_no_response_body_or_credentials
    %w[401 402 404 429 500].each do |code|
      with_http_response(code:, body: 'fixture-only private-provider-message') do |result|
        assert_equal 'cli_failure', result.fetch('failure_stage')
        assert_includes result.fetch('reason'), "HTTP #{code}"
        refute_includes JSON.generate(result), 'private-provider-message'
        refute result.key?('diagnostic_path')
      end
    end
  end

  def test_malformed_json_stays_a_report_failure
    with_http_response(body: '{broken') do |result|
      assert_equal 'report_validation', result.fetch('failure_stage')
      assert_equal 'not_eligible', result.fetch('skip_evidence')
    end
  end

  def test_invalid_provider_bytes_stay_a_report_failure
    with_http_response(body: "{\"model\":\"\xff\"}".b) do |result|
      assert_equal 'report_validation', result.fetch('failure_stage')
    end
  end

  def test_timeout_and_network_failure_are_explicit_without_retries
    [Timeout::Error, SocketError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError,
     Zlib::DataError].each do |error|
      with_adapter do |cli, _options, _report|
        with_request(->(*) { raise error, 'private diagnostic' }) do
          result = cli.run('diff')
          assert_network_failure(result)
        end
      end
    end
  end

  def test_total_request_deadline_interrupts_a_slow_response
    replacement = ->(*) { sleep 0.1 }
    replacing_method(Net::HTTP, :start, replacement) do
      with_key do
        assert_raises(Timeout::Error) { Shaka::OpenrouterReview.request('diff', model: MODEL, effort: nil, timeout: 0.001) }
      end
    end
  end

  private

  def assert_network_failure(result)
    assert_equal 'cli_failure', result.fetch('failure_stage')
    assert_true result.fetch('attempted')
    refute_includes JSON.generate(result), 'private diagnostic'
  end

  def with_http_response(code: '200', body: JSON.generate(completion))
    response = Net::HTTPResponse::CODE_TO_OBJ.fetch(code).new('1.1', code, 'fixture')
    response.instance_variable_set(:@read, true)
    response.body = body
    replacing_method(Net::HTTP, :start, http_transport(response)) do
      with_adapter { |cli, _options, _report| yield(cli.run('diff') || completion) }
    end
  end

  def http_transport(response)
    lambda do |*endpoint, **options, &block|
      @endpoint = endpoint
      @http_options = options
      http = fake_http(response)
      result = block.call(http)
      @request = http.instance_variable_get(:@request)
      result
    end
  end

  def fake_http(response)
    http = Object.new
    http.define_singleton_method(:request) do |request|
      @request = request
      response
    end
    http
  end
end
