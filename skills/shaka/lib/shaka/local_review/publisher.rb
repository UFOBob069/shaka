# frozen_string_literal: true

require_relative 'loop_comment'
require_relative 'history'
require_relative 'rebased_commits'

module Shaka
  # Preflights every comment, then upserts the main comment and any continuations. A retry resumes
  # partial publication.
  class LocalReviewPublisher
    def initialize(content, github, repository)
      @content = content
      @github = github
      @repository = repository
      @commits = {}
    end

    def publish
      summary = LocalReviewComment.new(@content).loop_summary
      parts = loop_comment.parts
      parts.each { |part| part.check_rendering!(@github.verify_rendering(part.body)) }
      results = parts.map { |part| @github.reply(body: part.body, key: part.key) }
      { 'comments' => results, 'summary' => summary, 'cleanup' => cleanup(results, parts.size) }
    end

    private

    def loop_comment
      @loop_comment ||= LocalReviewLoopComment.new(@content, repository: @repository,
                                                             usage_url: "https://github.com/#{@repository}/pull/#{@github.number}",
                                                             published: ->(sha) { !commit(sha).nil? },
                                                             rebased:,
                                                             subject: ->(sha) { subject(sha) })
    end

    # Also retires comments this ledger replaced: per-commit comments of earlier commits holding only
    # its reports, and continuations a repacking no longer writes. Like any report of the current
    # commit, a per-commit one stays visible. A failed lookup is reported, never mistaken for nothing to retire.
    def cleanup(results, count)
      begin
        replaced = replaced(count)
      rescue Error => e
        return { 'collapsed' => [], 'unavailable' => ["Replaced review comments could not be listed: #{e.message}"] }
      end
      LocalReviewHistory.new(@github, ids: results.map { |result| result.fetch('id') } + replaced).collapse
    end

    def replaced(count)
      stale = /\A<!-- shaka:reply:#{Regexp.escape(loop_comment.key)}-(\d+) -->\n/
      @github.issue_comments.filter_map do |comment|
        body = comment['body'].to_s
        comment['id'] if per_commit?(body) || body[stale, 1].to_i >= count
      end
    end

    # Every report the comment holds, one per round disclosure, must be one of this ledger's.
    def per_commit?(body)
      head = body[/\A<!-- shaka:reply:local-review-(\h{40}) -->\n/, 1]
      return false unless head

      held = loop_comment.reports(head).count { |report| body.include?(report) }
      held.positive? && held == body.scan(/<summary>Round \d+ · #{head[0, 7]} · /).size
    end

    def rebased = @rebased ||= LocalReviewRebasedCommits.new(@github, @repository)

    def rebased_commit(sha)
      copy = rebased.call(sha)
      commit(copy) if copy
    end

    # Cache both the subject and existence; a 404 names an unpushed or replaced commit.
    # Other failures stop publication before any comment is written.
    def commit(sha)
      @commits.fetch(sha) do
        @commits[sha] = @github.api("repos/#{@repository}/git/commits/#{sha}")
      rescue Shaka::Error => e
        raise unless e.http_status == 404

        @commits[sha] = nil
      end
    end

    def subject(sha)
      text = (commit(sha) || rebased_commit(sha))&.fetch('message', nil).to_s.lines.first.to_s.strip
      return 'Commit subject unavailable.' if text.empty?

      # A commit subject is data, not Markdown that may hide the generated review layout.
      "<code>#{text.each_char.map { |char| "&##{char.ord};" }.join}</code>"
    end
  end
end
