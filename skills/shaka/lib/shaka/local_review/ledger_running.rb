# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require_relative '../error'

module Shaka
  # Marks the reviews still running on a commit, so its findings are recorded only after every
  # reviewer finishes and one triage sees all of them. A running review holds a file lock of its
  # own for as long as it runs; the system releases it when the process exits, even when killed,
  # so a mark whose lock is free belongs to a review that is no longer running.
  module LocalReviewLedgerRunning
    # Checks a round may start and marks its reviewer running. Another commit waits until every
    # review of the current one has finished.
    def start!(base:, head:, reviewer:, max_rounds: RepositoryConfig::ReviewLimit::DEFAULT,
               budget: nil)
      locked do
        budget = task_budget(base, budget)
        budget&.check_available!
        check_next!(base:, head:, reviewer:, max_rounds: budget&.limit || max_rounds)
        check_not_running!(head, reviewer)
        yield if block_given?
        budget&.consume!
        save_task_budget(base, budget)
        write_running(running + [hold(head, reviewer)])
      end
    end

    # Clears this ledger's marks after a run that ended without a round, such as a failed reviewer.
    def finish! = locked { clear_running }

    private

    def running = data.fetch('running', [])

    # Takes a lock file only this run holds, and returns the mark that names it.
    def hold(head, reviewer)
      path = "#{@path}.running-#{SecureRandom.hex(8)}"
      file = File.new(path, File::RDWR | File::CREAT | File::EXCL, 0o600)
      file.flock(File::LOCK_EX)
      (@held ||= {})[path] = file
      { 'head' => head, 'reviewer' => reviewer, 'lock' => path }
    end

    # One review of a commit per reviewer at a time, and no new commit while another is being read.
    def check_not_running!(head, reviewer)
      elsewhere = running.find { |entry| entry['head'] != head && live?(entry) }
      raise Error, "Wait for #{elsewhere['reviewer']} to finish reviewing #{elsewhere['head']}." if elsewhere
      return unless live(head).any? { |entry| entry['reviewer'].to_s.casecmp?(reviewer.to_s) }

      raise Error, "#{reviewer} is already reviewing #{head}; wait for that review."
    end

    def live(head) = running.select { |entry| entry['head'] == head && live?(entry) }

    # A mark is live while some process holds its lock file. Only this ledger's own lock files
    # count, so a mark naming another path is ended and nothing outside the ledger is touched.
    def live?(entry)
      return false unless own_lock?(entry)

      File.open(entry['lock'], File::RDWR) { |file| !file.flock(File::LOCK_EX | File::LOCK_NB) }
    rescue SystemCallError
      false
    end

    def own_lock?(entry) = entry['lock'].to_s.match?(/\A#{Regexp.escape(@path)}\.running-\h{16}\z/)

    # Releases this ledger's own marks, then drops every mark whose review has ended.
    def clear_running
      (@held || {}).each_value(&:close)
      @held = {}
      prune_running
    end

    def prune_running
      ended, live = running.partition { |entry| !live?(entry) }
      ended.select { |entry| own_lock?(entry) }.each { |entry| FileUtils.rm_f(entry['lock']) }
      write_running(live)
    end

    def write_running(entries)
      write(entries.empty? ? data.except('running') : data.merge('running' => entries))
    end

    # Any live review blocks a record: one of this commit is still reading it, and one of a newer
    # commit would find the ledger changed under it.
    def check_nothing_running!
      waiting = running.select { |entry| live?(entry) }
      return if waiting.empty?

      raise Error, "Wait for #{waiting.map { |entry| entry['reviewer'] }.join(' and ')} to finish reviewing " \
                   "#{waiting.map { |entry| entry['head'] }.uniq.join(' and ')} before recording."
    end
  end
end
