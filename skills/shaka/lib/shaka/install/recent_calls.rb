# frozen_string_literal: true

require 'json'
require 'time'
require_relative '../call_log'
require_relative 'refusal'

module Shaka
  module Install
    # Stops a manual update while the call log shows Shaka in use, because updating the one source
    # checkout changes files that open chats are still reading. Without a call log, nothing is known
    # and the update proceeds. A call still running has no record yet, because records are written
    # at exit.
    class RecentCalls
      WINDOW = 15 * 60
      # The newest records are at the end; a day of heavy use stays well inside this tail.
      TAIL_BYTES = 256 * 1024
      # The installer's own records would block the retry of a stopped update. `update-check` runs at
      # the start of every Claude chat with the session hook, and its answer is what sends a person
      # here, so neither shows a chat working with Shaka files.
      IGNORED = %w[install update-check].freeze

      def initialize(env: ENV, now: Time.now)
        @path = CallLog.path(env)
        @now = now
      end

      def check(helper)
        call = latest
        return unless call && @now - call.fetch(:ended) < WINDOW

        raise ArgumentError, Refusal.message(
          'Shaka was used in the last 15 minutes, and updating now changes files open chats are reading',
          "#{call.fetch(:command)} ended at #{call.fetch(:ended).utc.iso8601} in #{@path}",
          "finish open Shaka chats, then run #{Refusal.command(helper, 'install', '--update')}",
          note: "To update anyway, run #{Refusal.command(helper, 'install', '--update', '--force')}"
        )
      end

      private

      def latest
        return unless @path && File.file?(@path)

        tail.lines.filter_map { |line| call(line) }.max_by { it.fetch(:ended) }
      end

      def tail
        File.open(@path, 'rb') do |file|
          file.seek([file.size - TAIL_BYTES, 0].max)
          file.read.force_encoding(Encoding::UTF_8).scrub
        end
      end

      def call(line)
        record = JSON.parse(line)
        return unless record.is_a?(Hash) && !IGNORED.include?(record['command'])

        ended = Time.iso8601(record.fetch('at')) + (record['duration_ms'].to_i / 1000.0)
        { command: record['command'].to_s, ended: }
      rescue JSON::ParserError, KeyError, ArgumentError, TypeError
        nil
      end
    end
  end
end
