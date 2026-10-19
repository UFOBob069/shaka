# frozen_string_literal: true

require_relative '../error'
require_relative '../post_implementation_report'
require_relative 'history'

module Shaka
  # Checks this account's published checkpoint facts, not the reviewer's product judgment.
  class PostImplementationEvidence
    MARK = 'shaka:post-implementation'
    ATTESTATION = /\n<!-- #{MARK} ([0-9a-f]{40}) (ready|blocked|opted_out|not_completed) -->\s*\z/

    def self.attestation(head, state) = "<!-- #{MARK} #{head} #{state} -->"

    # The owner's disposition sits on the line directly above the attestation, so free text earlier in the
    # report cannot plant one, and it counts only when it agrees with the attested state.
    RECOMMENDATION = PostImplementationReport::RECOMMENDATIONS.join('|')
    DISPOSITION = Regexp.new("\n<!-- #{MARK}-disposition (#{RECOMMENDATION}) -->" \
                             "\n<!-- #{MARK} ([0-9a-f]{40}) (ready|blocked) -->\\s*\\z")
    def self.disposition(recommendation) = "<!-- #{MARK}-disposition #{recommendation} -->"

    def initialize(github, enabled: true)
      @github = github
      @enabled = enabled
    end

    def call(head)
      return { 'basis' => 'trusted_opt_out' } if @enabled == false

      comment = latest
      reviewed, state = comment&.fetch('body', '').to_s.match(ATTESTATION)&.captures
      unless reviewed == head && %w[ready opted_out].include?(state)
        raise Error, "Checkpoint is missing, stale, or blocked for #{head}; " \
                     'run and publish the checkpoint for this head before final preparation.'
      end

      { 'basis' => state, 'head' => reviewed, 'comment' => comment['html_url'] }.compact
    end

    # The latest checkpoint's owner recommendation, or nil when that checkpoint is for another head or has none.
    def recommendation(head)
      recommendation, reviewed, state = latest&.fetch('body', '').to_s.match(DISPOSITION)&.captures
      recommendation if reviewed == head && (recommendation == 'Merge') == (state == 'ready')
    end

    private

    def latest
      account = @github.viewer_login
      checkpoints = @github.issue_comments.select do |entry|
        entry.dig('user', 'login') == account && entry['body'].to_s.match?(PostImplementationHistory::KEY)
      end
      checkpoints.max_by { |entry| CommentHistory.order(entry) }
    end
  end
end
