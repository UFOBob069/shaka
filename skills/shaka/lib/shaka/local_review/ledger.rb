# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative 'bundle'
require_relative 'evidence'
require_relative 'finding'
require_relative 'ledger_batch'
require_relative 'ledger_running'
require_relative 'budget'
require_relative 'triage_history'
require_relative '../repository_config/review_schema'

module Shaka
  # Private record of a local review loop: each round's commit, reviewer settings, report, and
  # what became of its findings. It stays outside the checkout until `review publish` renders it,
  # and it has the same shape as that command's content file. Rounds that share a commit form a
  # batch: several reviewers read that commit, and once none is still running, one record triages
  # all their findings together.
  class LocalReviewLedger
    include LocalReviewLedgerBatch
    include LocalReviewLedgerRunning
    include LocalReviewLedgerBudget
    include LocalReviewTriageHistory

    class RoundCap < Error; end

    attr_reader :path

    # Only `review run` can start a ledger, so only it needs the checkout to keep the ledger out of.
    # The path resolves its directory's links, so every spelling of one ledger, such as `/tmp` and
    # `/private/tmp` on macOS, names the same running marks.
    def initialize(path, root: nil)
      directory = File.realpath(File.dirname(File.expand_path(path)))
      @path = File.join(directory, File.basename(path))
      raise Error, '--ledger must be outside the candidate checkout' if
        root && (directory == root || directory.start_with?("#{root}/"))
    end

    def rounds = data.fetch('rounds')

    def recorded_batch_fixes(source = rounds)
      batch.flat_map do |index|
        LocalReviewFinding.list(source[index]['findings'], "round #{index + 1} finding").select(&:fixed?)
      end.map(&:commit)
    end

    def last_head = rounds.last&.fetch('head')

    # The newest head reviewed before this one: the last batch's commit, or for another reviewer
    # joining the last batch, the batch before it.
    def previous_head(head) = rounds.reverse.find { |round| round['head'] != head }&.fetch('head')

    # A round reviews a new commit on the same base, after the previous batch's findings are
    # recorded, or joins the last batch with a reviewer that has not read that commit. The cap
    # counts reviewed commits, so another reviewer of the last one does not use a turn.
    def check_next!(base:, head:, reviewer:, max_rounds: RepositoryConfig::ReviewLimit::DEFAULT)
      check_cap!(max_rounds) unless !rounds.empty? && head == last_head
      check_joins!(base, head, reviewer)
      check_batch_recorded! unless rounds.empty? || head == last_head
    end

    # The newest disposition of every finding so far, keyed by the id rounds share. A commit's
    # rounds are recorded only after all of them finish, so no reviewer sees a sibling's findings.
    def prior_findings
      rounds.each_with_index.with_object({}) do |(round, index), latest|
        LocalReviewFinding.list(round['findings'], "round #{index + 1} finding").each do |finding|
          latest[finding.id] = finding
        end
      end.values
    end

    # The rounds a run's start checks read: every round except those on its own commit.
    def snapshot(head) = rounds.reject { |round| round['head'] == head }

    # Reviewers of one commit run at once, so each append rereads the ledger under a lock. Only
    # other reviewers of the same commit may have landed since `snapshot`; any other change means
    # the start checks read a ledger that no longer exists.
    def append!(base:, round:, snapshot: nil, max_rounds: RepositoryConfig::ReviewLimit::DEFAULT)
      locked do
        append_current_round!(base:, round:, snapshot:, max_rounds: self.max_rounds(max_rounds))
      end
    end

    # Records what became of every finding on the last commit in one triage, once none of its
    # reviews is still running, and returns the round numbers it recorded. With several
    # reviewers, each finding names the ones that reported it, so a shared finding is one entry.
    def record!(content, head: nil)
      raise Error, 'Record content must be an object.' unless content.is_a?(Hash)

      locked do
        # Reviews still running explain an empty ledger better than the ledger does.
        check_nothing_running!
        select_record_batch!(head)

        record_current!(content)
        prune_running
        batch.map { |index| index + 1 }
      end
    ensure
      @record_head = nil
    end

    private

    def append_current_round!(base:, round:, snapshot:, max_rounds:)
      check_next!(base:, head: round['head'], reviewer: round['reviewer'], max_rounds:)
      raise Error, 'The ledger changed while this round ran; run the review again.' if
        snapshot && snapshot(round['head']) != snapshot

      kept = round.merge(LocalReviewBundle.store(@path, round.fetch('report')))
      write(data.merge('version' => LocalReviewBundle::VERSION, 'base' => base, 'local_max_rounds' => max_rounds,
                       'rounds' => rounds + [kept]))
      clear_running
    end

    def data
      @data ||= if File.exist?(@path)
                  LocalReviewBundle.ledger!(JSON.parse(File.read(@path, encoding: 'UTF-8')), @path)
                else
                  { 'rounds' => [] }
                end
    end

    def check_joins!(base, head, reviewer)
      return if rounds.empty?
      raise Error, "The ledger's rounds measure the change against #{data['base']}; use a new ledger." unless
        data['base'] == base

      check_new_head!(head, reviewer)
    end

    def locked
      File.open("#{@path}.lock", File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        @data = nil
        yield
      end
    end

    def recorded?(round) = round.key?('findings') || reported_count(round).zero?

    # The count check keeps a finding from dropping out between the report and the comment.
    def check_findings!(round, number)
      findings = LocalReviewFinding.list(round['findings'], "round #{number} finding")
      reported = reported_count(round)
      return if findings.size == reported

      raise Error, "Round #{number}'s report counts #{reported} findings; #{findings.size} were recorded."
    end

    def reported_count(round)
      match = File.read(round.fetch('report'), encoding: 'UTF-8').match(LocalReviewEvidence::CLOSING)
      raise Error, "Round report #{round['report']} has no FINDINGS count." unless match

      match[2].to_i
    end

    def write(content)
      temporary = "#{@path}.#{Process.pid}.tmp"
      File.write(temporary, "#{JSON.pretty_generate(content)}\n", perm: 0o600)
      File.rename(temporary, @path)
      @data = content
    end
  end
end
