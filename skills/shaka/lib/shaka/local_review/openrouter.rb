# frozen_string_literal: true

require 'json'
require 'net/http'
require 'timeout'
require 'securerandom'
require_relative '../usage/openrouter_usage'
require_relative '../usage/value_token'

module Shaka
  # One fixed model, one bounded request, no tools or automatic model fallback.
  class OpenrouterReview
    MODEL = 'deepseek/deepseek-v4.1-flash'
    EFFORTS = %w[low high max].freeze
    ENDPOINT = URI('https://openrouter.ai/api/v1/chat/completions')

    def self.validate!(options)
      raise Error, "deepseek/openrouter requires --model #{MODEL}" unless options[:model] == MODEL
      return if options[:effort].nil? || EFFORTS.include?(options[:effort])

      raise Error, "deepseek/openrouter effort must be #{EFFORTS.join(', ')}"
    end

    def self.request(prompt, model:, effort:, timeout:)
      raise Error, 'Review prompt is not UTF-8' unless valid_prompt?(prompt)

      prompt = prompt.dup.force_encoding(Encoding::UTF_8)
      body = { model:, messages: [{ role: 'user', content: prompt }], stream: false, max_tokens: 65_536,
               provider: { require_parameters: true } }
      body[:reasoning] = { effort: } if effort
      post(body, timeout)
    end

    def self.token(value) = UsageValue.token(value)

    def self.valid_prompt?(prompt)
      prompt.is_a?(String) && prompt.dup.force_encoding(Encoding::UTF_8).valid_encoding?
    end

    def self.credentials_error
      key = ENV.fetch('OPENROUTER_API_KEY', '').b
      return ['OPENROUTER_API_KEY is missing', 'credentials_missing'] if key.strip.empty?

      ['OPENROUTER_API_KEY contains invalid characters', 'credentials_invalid'] unless key.match?(/\A[\x21-\x7e]+\z/)
    end

    def self.post(body, timeout)
      error = credentials_error
      raise Error, error.first if error

      request = Net::HTTP::Post.new(ENDPOINT, 'Content-Type' => 'application/json',
                                              'Authorization' => "Bearer #{ENV.fetch('OPENROUTER_API_KEY')}")
      request.body = JSON.generate(body)
      response = send_request(request, timeout)
      raise Error, "OpenRouter HTTP #{response.code}; no retry or model substitution" unless
        response.is_a?(Net::HTTPSuccess)

      decode(response.body)
    end

    def self.decode(body)
      text = body.to_s.dup.force_encoding(Encoding::UTF_8)
      raise JSON::ParserError, 'Invalid UTF-8 response' unless text.valid_encoding?

      JSON.parse(text)
    end

    def self.send_request(request, timeout)
      Timeout.timeout(timeout) do
        Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: timeout,
                                                      read_timeout: timeout, write_timeout: timeout,
                                                      max_retries: 0) { |http| http.request(request) }
      end
    end
    private_class_method :post, :send_request, :decode
  end

  # Reuses review attestation and ledger handling; API diagnostics never retain response prose.
  module LocalReviewOpenrouter
    NETWORK_ERRORS = [SystemCallError, IOError, SocketError, OpenSSL::SSL::SSLError, Net::ProtocolError,
                      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Zlib::Error].freeze

    private

    def openrouter(prompt)
      OpenrouterReview.validate!(@options)
      error = OpenrouterReview.credentials_error
      return outcome(*error, false) if error
      return outcome('Review prompt is not UTF-8', 'setup_failure', false) unless OpenrouterReview.valid_prompt?(prompt)

      request_openrouter(prompt)
    end

    def request_openrouter(prompt)
      result = fetch_openrouter(prompt)
      openrouter_result(result)
    rescue JSON::ParserError, TypeError
      invalid('OpenRouter returned malformed JSON')
    rescue Timeout::Error
      failure("OpenRouter timed out after #{@options.fetch(:timeout_seconds)}s; no retry")
    rescue Error => e
      failure(e.message)
    rescue *NETWORK_ERRORS
      openrouter_io_failure(result)
    end

    def fetch_openrouter(prompt)
      OpenrouterReview.request(prompt, model: @options[:model], effort: @options[:effort],
                                       timeout: @options.fetch(:timeout_seconds))
    end

    def openrouter_io_failure(result)
      return outcome('OpenRouter response received; local evidence write failed', 'evidence_write', true) if result

      failure('OpenRouter network/TLS request failed; no retry')
    end

    def openrouter_result(result)
      return invalid('OpenRouter returned non-object JSON') unless result.is_a?(Hash)

      capture_openrouter_usage(result)
      return failure('OpenRouter reported an API error; no retry or model substitution') if result['error']

      choice = openrouter_choice(result['choices'])
      return invalid('OpenRouter returned an incomplete review') unless choice && choice['finish_reason'] == 'stop'

      write_openrouter_report(choice['message'])
    end

    def openrouter_choice(choices)
      choices.first if choices.is_a?(Array) && choices.one? && choices.first.is_a?(Hash)
    end

    def write_openrouter_report(message)
      text = message['content'] if message.is_a?(Hash)
      return invalid('OpenRouter returned no text review') unless text.is_a?(String) && !text.strip.empty?

      File.write(@report, text)
      nil
    end

    def capture_openrouter_usage(result)
      @options[:observed_model] = OpenrouterReview.token(result['model'])
      return unless @options.fetch(:capture_usage, true)

      # Retain only aggregate metadata, never candidate code, reasoning or credentials.
      usage = result['usage'].is_a?(Hash) ? result['usage'] : {}
      metadata = openrouter_metadata(result)
      metadata['usage'] = openrouter_counters(usage)
      capture_openrouter_details(metadata, usage)
      @options[:usage] = save_usage(JSON.generate(metadata))
    end

    def openrouter_counters(usage)
      usage.slice('prompt_tokens', 'completion_tokens', 'total_tokens')
           .transform_values { |value| OpenrouterUsage.counter(value) }
           .merge('cost' => OpenrouterUsage.cost(usage['cost']))
    end

    def openrouter_metadata(result)
      { 'id' => OpenrouterReview.token(result['id']) || SecureRandom.uuid,
        'model' => @options[:observed_model], 'created' => OpenrouterUsage.counter(result['created']),
        'shaka_openrouter' => 1, 'requested_model' => @options[:model], 'effort' => @options[:effort] }
    end

    def capture_openrouter_details(metadata, usage)
      %w[prompt_tokens_details completion_tokens_details].each do |key|
        details = usage[key]
        next unless details.is_a?(Hash)

        metadata['usage'][key] = details.slice('cached_tokens', 'cache_write_tokens', 'reasoning_tokens')
                                        .transform_values { |value| OpenrouterUsage.counter(value) }
      end
    end
  end
end
