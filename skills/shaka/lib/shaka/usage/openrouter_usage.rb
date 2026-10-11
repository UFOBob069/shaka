# frozen_string_literal: true

require 'json'
require 'time'
require_relative 'response_count'

module Shaka
  # Reads only Shaka's aggregate API metadata, with response IDs shared across copied files.
  class OpenrouterUsage
    include ResponseCount

    HOST = 'OpenRouter'
    NOTE = 'OpenRouter input includes cached tokens; output includes reasoning. USD is the reported account charge ' \
           'in OpenRouter credits (USD), not direct DeepSeek pricing. Absent counters or cost remain UNKNOWN.'
    LATEST_SCOPE = 'the last API response in the first supplied file'
    INCLUSIVE_INPUT = true
    COUNTERS = { 'input_tokens' => 'prompt_tokens', 'output_tokens' => 'completion_tokens',
                 'total_tokens' => 'total_tokens' }.freeze

    attr_reader :responses, :versions, :gaps

    def self.discover = []

    def initialize(files, turns, all_turns: false)
      @responses = {}
      @versions = []
      @gaps = []
      count_selected(files.map { |file| read(file) }, turns, all_turns)
    end

    def self.counter(value)
      value if value.is_a?(Integer) && value >= 0
    end

    def self.cost(value)
      value if value.is_a?(Numeric) && value.finite? && value >= 0
    end

    private

    def read(file)
      text = File.read(file, encoding: 'UTF-8')
      return unreadable unless text.valid_encoding?

      data = JSON.parse(text)
      return unreadable unless data.is_a?(Hash) && data['shaka_openrouter'] == 1 && turn?(data['id'])

      @versions << '1'
      identity = data['id']
      [{ identity => response(data, identity) }, identity]
    rescue SystemCallError, EncodingError, JSON::ParserError
      unreadable
    end

    def response(data, identity)
      { 'response_id' => identity, 'turn_id' => identity, 'timestamp' => timestamp(data['created']),
        'configuration' => ['deepseek', data['requested_model'], data['model'], data['effort']],
        'usage' => tokens(data['usage']) }
    end

    def timestamp(value)
      Time.at(value).utc.iso8601 if value.is_a?(Integer) && value >= 0 && value <= 253_402_300_799
    end

    def tokens(usage)
      return { 'native_cost_usd' => nil } unless usage.is_a?(Hash)

      COUNTERS.transform_values { |key| self.class.counter(usage[key]) }.merge(
        'cached_input_tokens' => detail(usage, 'prompt_tokens_details', 'cached_tokens'),
        'cache_write_input_tokens' => detail(usage, 'prompt_tokens_details', 'cache_write_tokens'),
        'reasoning_output_tokens' => detail(usage, 'completion_tokens_details', 'reasoning_tokens'),
        'native_cost_usd' => self.class.cost(usage['cost']), 'native_cost_source' => 'openrouter'
      )
    end

    def detail(usage, group, field)
      self.class.counter(usage[group][field]) if usage[group].is_a?(Hash)
    end

    def unreadable
      @gaps << 'Unreadable or unidentifiable OpenRouter metadata'
      [{}, nil]
    end
  end
end
