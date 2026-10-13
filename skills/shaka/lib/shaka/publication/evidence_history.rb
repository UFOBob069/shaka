# frozen_string_literal: true

require_relative 'comment_history'

module Shaka
  # The agent selects which of this account's AI-authored comments a newer one replaced.
  # Ruby does not parse evidence formats or decide which evidence is obsolete.
  class EvidenceHistory < CommentHistory
    MARKER = 'Superseded — read the current evidence:'
    SUMMARY = 'Earlier evidence'
    KEY = /\A🤖 [^\n]+\n\n/

    def collapse(ids, current:)
      report = { 'collapsed' => [], 'unavailable' => [] }
      @account = @github.viewer_login
      raise Error, 'Authenticated GitHub login is unavailable.' unless @account.is_a?(String) && !@account.empty?

      latest = current_comment(current)
      ids.uniq.each { |id| fold_one({ 'id' => id }, latest, report) }
      report
    rescue Error => e
      report['unavailable'] << e.message
      report
    end

    private

    def current_comment(id)
      comment = @github.api("repos/#{@github.repository}/issues/comments/#{id}")
      raise Error, "Comment #{id}: Current comment is not this account's AI-authored comment here." unless
        owned?(comment)
      raise Error, "Comment #{id}: Current comment is already folded." if archived?(comment['body'])

      comment
    end

    def owned?(comment)
      super && comment['issue_url'].to_s.end_with?("/#{@github.repository}/issues/#{@github.number}")
    end

    def fresh_body(path, latest)
      source = @github.api(path)
      raise Error, "Selected comment is not this account's AI-authored comment here." unless owned?(source)
      raise Error, 'Selected comment is not earlier than the current one.' unless earlier?(source, latest)

      source.fetch('body')
    end

    def parts(body)
      identity = body[KEY]
      [identity, body.delete_prefix(identity)]
    end
  end
end
