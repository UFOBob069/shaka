# frozen_string_literal: true

require_relative '../error'
require_relative 'history'

module Shaka
  # Checks this account's published checkpoint facts, not the reviewer's product judgment.
  class PostImplementationEvidence
    MARK = 'shaka:post-implementation'
    ATTESTATION = /\n<!-- #{MARK} ([0-9a-f]{40}) (ready|blocked|opted_out|not_completed) -->\s*\z/

    def self.attestation(head, state) = "<!-- #{MARK} #{head} #{state} -->"

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

    private

    def latest
      account = @github.viewer_login
      @github.issue_comments.reverse.find do |entry|
        entry.dig('user', 'login') == account && entry['body'].to_s.match?(PostImplementationHistory::KEY)
      end
    end
  end
end
