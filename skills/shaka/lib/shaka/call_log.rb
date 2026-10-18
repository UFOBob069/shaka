# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'

module Shaka
  # Appends one timing record per helper call to a local file, so a retrospective can
  # measure slow and failing steps. Records name the command, never its arguments, which
  # can hold private task text. Nothing is uploaded, and a failed write never changes
  # the command's result. The record is written at exit, so a call that replaces this
  # process, as a successful `shaka work` launch does, leaves none.
  module CallLog
    VARIABLE = 'SHAKA_CALL_LOG'
    # Only these names are recorded, so a mistyped call cannot put an argument in the log.
    COMMANDS = %w[attention checkpoint claim comments description doctor enforcement evidence handoff install
                  issue-create merge post-implementation pr prefix recommendation reply repos resolve review
                  review-prompt reviewer seam squash-message trial update-check usage walkthrough work
                  workflow].freeze
    # Commands whose second word selects the operation; any other second word is an argument.
    # A test keeps them equal to each command's own list.
    OPERATIONS = { 'evidence' => %w[run bind verify guard], 'post-implementation' => %w[run publish],
                   'pr' => %w[watch], 'repos' => %w[add refresh],
                   'review' => %w[run check record assess publish collapse],
                   'seam' => %w[check init pointer migrate upgrade private preview],
                   'trial' => %w[prepare report] }.freeze
    # The fixed commands `evidence run` accepts; any other `--command` value is not recorded.
    CHECKS = %w[setup test validate validate_local trigger_hosted_ci].freeze

    module_function

    def start(arguments, env: ENV)
      path = path(env)
      return unless path

      identity = identity(arguments)
      started_at = Time.now.utc
      started = clock
      at_exit { append(path, { 'at' => started_at.iso8601, **identity, 'exit' => exit_status, **elapsed(started) }) }
    end

    # Runs the block and returns its value with when it started and how long it took.
    def measure
      started_at = Time.now.utc
      started = clock
      value = yield
      [value, { 'started_at' => started_at.iso8601, **elapsed(started) }]
    end

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def elapsed(started) = { 'duration_ms' => ((clock - started) * 1000).round }

    def path(env)
      value = env[VARIABLE].to_s
      return if value == 'off'
      return File.expand_path(value) unless value.empty?

      File.join(Dir.home, '.local', 'state', 'shaka', 'calls.jsonl')
    rescue ArgumentError
      nil
    end

    def identity(arguments)
      first, second = arguments
      words = [COMMANDS.include?(first) ? first : 'unknown']
      words << second if OPERATIONS.fetch(first, []).include?(second)
      record = { 'command' => words.join(' ') }
      check = arguments[arguments.index('--command').to_i + 1] if arguments.include?('--command')
      record['check'] = check if CHECKS.include?(check)
      record
    end

    def exit_status
      error = $! # rubocop:disable Style/SpecialGlobalVars
      return 0 unless error

      error.is_a?(SystemExit) ? error.status : 1
    end

    def append(path, record)
      FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
      File.write(path, "#{JSON.generate(record)}\n", mode: 'a', perm: 0o600)
    rescue StandardError => e
      warn "shaka: call log not written: #{e.message}"
    end
  end
end
