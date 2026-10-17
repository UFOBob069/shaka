# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative 'budget_limits'

module Shaka
  module Evaluation
    # An append is durable before its caller may launch a trial. A broken tail fails closed.
    class BudgetLedger
      START = %w[version event id month kind scope cap].freeze
      SETTLE = %w[version event id dollars digest].freeze
      UUID = /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/
      DIGEST = /\Asha256:[0-9a-f]{64}\z/

      def initialize(directory)
        @directory = directory
        @path = File.join(directory, 'budget.jsonl')
      end

      def transaction
        FileUtils.mkdir_p(@directory, mode: 0o700)
        File.open(@path, File::RDWR | File::CREAT, 0o600) do |file|
          lock(file)
          calls = read(file)
          result, event = yield calls
          append(file, calls, event) if event
          result
        end
      rescue JSON::ParserError, ArgumentError, KeyError, TypeError
        raise BudgetError, 'Invalid budget ledger'
      end

      private

      def lock(file)
        file.flock(File::LOCK_EX)
        file.chmod(0o600)
      end

      def read(file)
        file.each_line.with_object({}) do |line, calls|
          raise BudgetError, 'Incomplete budget ledger' unless line.end_with?("\n")

          apply(calls, JSON.parse(line))
        end
      end

      def append(file, calls, event)
        apply(calls, event)
        file.seek(0, IO::SEEK_END)
        file.write("#{JSON.generate(event)}\n")
        file.flush
        file.fsync
        File.open(@directory, File::RDONLY, &:fsync)
      end

      def apply(calls, event)
        raise BudgetError, 'Invalid budget event' unless event.is_a?(Hash) && event['version'] == 1

        case event['event']
        when 'start' then start(calls, event)
        when 'settle' then settle(calls, event)
        else raise BudgetError, 'Invalid budget event'
        end
      end

      def start(calls, event)
        raise BudgetError, 'Invalid budget reservation' unless valid_start?(event) && !calls.key?(event['id'])

        BudgetLimits.amount(event.fetch('cap'))
        calls[event['id']] = event.merge('dollars' => nil)
      end

      def valid_start?(event)
        event.keys.sort == START.sort && matches?(event['id'], UUID) &&
          matches?(event['month'], /\A\d{4}-(?:0[1-9]|1[0-2])\z/) &&
          BudgetLimits::KINDS.include?(event['kind']) && scope?(event['scope'])
      end

      def matches?(value, pattern) = value.is_a?(String) && value.match?(pattern)
      def scope?(value) = value.is_a?(String) && !value.empty?

      def settle(calls, event)
        valid = event.keys.sort == SETTLE.sort && event['digest'].is_a?(String) &&
                event['digest'].match?(DIGEST)
        raise BudgetError, 'Invalid budget settlement' unless valid

        call = calls.fetch(event['id'])
        raise BudgetError, 'Budget reservation already settled' if call['dollars']

        call['dollars'] = BudgetLimits.amount(event.fetch('dollars'))
      end
    end
  end
end
