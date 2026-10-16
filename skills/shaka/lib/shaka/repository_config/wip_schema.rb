# frozen_string_literal: true

require_relative '../defaults'
require_relative '../error'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the optional WIP Details policy.
    class WipSchema
      include Validation

      KEY = 'include_checkout_path'
      # The earlier name hid the chat locator too; it now sets the checkout path alone.
      LEGACY_KEY = 'include_locations'
      KEYS = [KEY, LEGACY_KEY].freeze

      def self.resolve(wip)
        { KEY => wip.fetch(KEY) { wip.fetch(LEGACY_KEY) { Defaults.fetch('wip', KEY) } } }
      end

      def initialize(wip)
        @wip = wip
      end

      def validate
        mapping!(@wip, 'wip')
        keys!(@wip, [], KEYS, 'wip')
        raise Error, "wip.#{LEGACY_KEY} is the earlier name of wip.#{KEY}; set only wip.#{KEY}" if @wip.size > 1

        @wip.each do |key, value|
          enum!(value, [true, false], "wip.#{key} must be true or false")
        end
      end
    end
  end
end
