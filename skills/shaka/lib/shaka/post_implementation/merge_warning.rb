# frozen_string_literal: true

require_relative '../publication/feature_guard'
require_relative '../publication/merge_warning_region'
require_relative '../publication/text'
require_relative 'history'

module Shaka
  # Keeps a blocked checkpoint visible across normal description refreshes.
  class PostImplementationMergeWarning
    OPEN = MergeWarningRegion::OPEN
    CLOSE = MergeWarningRegion::CLOSE
    DRAFT = <<~GRAPHQL
      mutation($id: ID!) {
        convertPullRequestToDraft(input: {pullRequestId: $id}) {
          pullRequest { id isDraft headRefOid }
        }
      }
    GRAPHQL

    def initialize(github)
      @github = github
      @path = "repos/#{github.repository}/pulls/#{github.number}"
    end

    def call(head:, publication:, published:)
      # Opting out of a review does not settle a previously published concern.
      return { 'state' => 'unchanged' } if publication.state == 'opted_out'

      current = @github.api(@path)
      verify_head(current, head)
      verify_published(published)
      return { 'state' => 'superseded' } unless latest?(published)

      # Ready publications leave warning clearance to the maintainer; they cannot erase a newer blocker.
      return { 'state' => 'unchanged', 'head' => head } if publication.state == 'ready'

      failure = draft_failure(head)
      update(current, head, publication.summary, published)
      raise Error, failure if failure

      { 'state' => 'blocked', 'head' => head }
    end

    private

    def update(current, head, summary, published)
      body = current['body'].to_s
      remaining = MergeWarningRegion.remove(body)
      updated = "#{warning(head, summary, published)}#{remaining}"
      raise Error, 'Merge warning exceeds GitHub description length.' if updated.length > 65_536

      @github.verify_rendering(updated) unless updated == body
      FeaturePublication.unchanged!(@github, body, current)
      write(updated) unless updated == body
    end

    def verify_published(published)
      id = published['id']
      raise Error, 'Published checkpoint has no valid identifier.' unless id.is_a?(Integer) && id.positive?
    end

    def latest?(published)
      account = @github.viewer_login
      comments = @github.issue_comments.select do |comment|
        comment.dig('user', 'login') == account && comment['body'].to_s.match?(PostImplementationHistory::KEY)
      end
      latest = comments.max_by { |comment| order(comment) }
      raise Error, 'Published checkpoint is absent from the comment listing; retry publication.' unless
        latest && latest['id'] >= published['id']

      latest['id'] == published['id']
    end

    def order(comment)
      time = WalkthroughText.submitted_at(comment.merge('submitted_at' => comment['created_at']))
      id = comment['id']
      raise Error, 'Checkpoint comment has no creation time or identifier.' unless
        time && id.is_a?(Integer) && id.positive?

      [time, id]
    end

    def verify_head(pull, head)
      return if pull['state'] == 'open' && pull.dig('head', 'sha') == head

      raise Error, 'Merge warning is not for the live open PR head; the checkpoint comment remains published.'
    end

    def warning(head, summary, published)
      url = PublicationText.single_line(published['html_url'], 'checkpoint URL')
      raise Error, 'Checkpoint URL must use HTTPS.' unless url.match?(%r{\Ahttps://[^\s]+\z})

      reason = summary.lines.map do |line|
        "> #{line.chomp.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')}"
      end.join("\n")
      "#{OPEN}\n> **⛔ Do not merge — post-implementation checkpoint blocked.**\n>\n#{reason}\n>\n" \
        '> Task owner: resolve the linked concerns and publish a new checkpoint for the current head. ' \
        "Keep this PR in draft until all required gates pass.\n>\n" \
        "> [Blocking report](#{url}) · Head #{PublicationText.commit(head, @github.repository)}. " \
        "Passing technical checks does not resolve this blocker.\n#{CLOSE}\n\n"
    end

    def make_draft(head)
      pull = @github.snapshot
      raise Error, 'PR changed before draft conversion; retry the checkpoint publication.' unless
        pull.values_at('state', 'headRefOid') == ['OPEN', head]
      return if pull['isDraft']

      changed = @github.graphql(DRAFT, id: pull.fetch('id')).dig('convertPullRequestToDraft', 'pullRequest')
      return if changed && changed.values_at('id', 'isDraft', 'headRefOid') == [pull['id'], true, head]

      raise Error, 'Draft conversion was not confirmed at the checkpoint head; inspect the PR before retrying.'
    end

    def draft_failure(head)
      make_draft(head)
      nil
    rescue Error, KeyError, TypeError => e
      e.message
    end

    def write(body)
      stored = @github.api(@path, method: 'PATCH', fields: { body: })
      return if stored['body'] == body

      raise Error, 'Stored merge warning does not match the submitted description; inspect the PR before retrying.'
    end
  end
end
