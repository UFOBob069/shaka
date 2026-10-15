# frozen_string_literal: true

require_relative '../error'
require_relative '../public_comments/bounded_list'

module Shaka
  # Recognizes a review body this command itself rendered.
  module WalkthroughText
    HEADING = /^# Code Walkthrough$/
    IDENTITY = /\A🤖 /
    # The linked short form carries the full SHA in its URL; the bare full form is how older walkthroughs end.
    LINKED = %r{\[`\h{7}`\]\(https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/commit/(\h{40})\)}
    FOOTER = /_Walkthrough for commit (?:`([0-9a-f]{40})`|#{LINKED})\. This is a COMMENT, not an approval\._/
    FOOTER_LINE = /\A#{FOOTER}\z/
    RENDERED_DETAILS = %r{</?details\b[^>]*>}i

    def self.walkthrough?(body, marker)
      body.start_with?("#{marker} ") || rendered?(body)
    end

    # A quoted walkthrough inside a fence, or a report that continues after the
    # footer, is not the review this command published.
    def self.rendered?(body)
      lines = visible_lines(body)
      opening_identity?(lines) && heading?(lines) && closing_footer?(lines)
    end

    def self.visible_lines(body) = unfenced(body).lines.map(&:strip).reject(&:empty?)

    def self.opening_identity?(lines) = lines.first&.match?(IDENTITY)

    def self.heading?(lines) = lines.any? { |line| line.match?(HEADING) }

    def self.closing_footer?(lines) = lines.last&.match?(FOOTER_LINE)

    def self.revision(body)
      unfenced(body).scan(FOOTER).last&.compact&.first
    end

    def self.unfenced(body) = body.gsub(/^```.*?^```/m, '')

    # Inspect GitHub's sanitized HTML, rather than parsing the source Markdown.
    def self.verify_archive!(html, footer_html: '')
      content = archive_without_footer(html.rstrip, footer_html.strip)
      return if contained_archive?(content)

      raise Error, 'GitHub did not keep the archived body inside its outer details block; history was left intact.'
    end

    def self.archive_without_footer(html, footer)
      return html if footer.empty?

      raise Error, 'GitHub did not render the history attestation outside the archive.' unless html.end_with?(footer)

      html.delete_suffix(footer)
    end

    def self.contained_archive?(html)
      depth = 0
      html.to_enum(:scan, RENDERED_DETAILS).each do
        match = Regexp.last_match
        depth += match[0].start_with?('</') ? -1 : 1
        return html[match.end(0)..].strip.empty? if depth.zero?
        return false if depth.negative?
      end
      false
    end

    # Equal timestamps use the review id, which GitHub assigns in creation order.
    # A later id is not earlier, so overlapping publishes still cannot point at each other.
    def self.earlier?(review, published)
      prior = submitted_at(review)
      current = submitted_at(published)
      return false unless prior && current
      return true if prior < current
      return false unless prior == current

      older_id?(review, published)
    end

    def self.older_id?(review, published)
      current = published['id']
      prior = review['id']
      current.is_a?(Integer) && prior.is_a?(Integer) && prior < current
    end

    def self.submitted_at(review)
      value = review['submitted_at']
      value if value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}T/)
    end
  end

  # Collapses earlier Code Walkthrough reviews after a new one is confirmed.
  #
  # Only a COMMENT review by the authenticated author is rewritten. The previous
  # body stays in the details block, including any later human edit of that text.
  # A failure is returned with the publication result and does not undo the new review.
  class WalkthroughHistory
    MARKER = 'Superseded — read the current walkthrough:'
    POINTER = /\A#{Regexp.escape(MARKER)} (\S+)/
    UPDATE = <<~GRAPHQL
      mutation($id: ID!, $body: String!) {
        updatePullRequestReview(input: {pullRequestReviewId: $id, body: $body}) {
          pullRequestReview { body }
        }
      }
    GRAPHQL

    def initialize(github) = @github = github

    def collapse(published)
      report = fresh_report
      url = review_url(published.fetch('id'))
      reviews = earlier_walkthroughs(published)
      return report if reviews.empty?

      account = authenticated_login
      reviews.each { |review| fold_one(review, url, account, report) }
      report
    rescue Error => e
      report['unavailable'] << e.message
      report
    end

    private

    def fresh_report = { 'collapsed' => [], 'left_intact' => [], 'unavailable' => [] }

    def earlier_walkthroughs(published)
      raise Error, 'Published walkthrough has no submission time.' unless WalkthroughText.submitted_at(published)

      list_reviews.select { |review| earlier_walkthrough?(review, published) }
    end

    def earlier_walkthrough?(review, published)
      review['id'] != published['id'] && review['state'] == 'COMMENTED' &&
        WalkthroughText.walkthrough?(review['body'].to_s, MARKER) && WalkthroughText.earlier?(review, published)
    end

    def fold_one(review, url, account, report)
      return report['left_intact'] << review['id'] unless review.dig('user', 'login') == account

      source = fresh_walkthrough(review, report)
      return unless source

      apply_revision(review, revised_body(source, url), source, report)
    rescue Error => e
      report['unavailable'] << "Review #{review['id']}: #{e.message}"
    end

    def fresh_walkthrough(review, report)
      source = @github.review(review['id'])['body'].to_s
      return source if WalkthroughText.walkthrough?(source, MARKER)

      report['unavailable'] << "Review #{review['id']} changed before collapse."
      nil
    end

    def apply_revision(review, revised, source, report)
      return if revised.nil? || revised == source

      replace_review(review, revised, source)
      report['collapsed'] << review['id']
    end

    def revised_body(body, url)
      return retarget(body, url) if body.start_with?("#{MARKER} ")

      wrap(body, url)
    end

    def retarget(body, url)
      return if body[POINTER, 1] == url

      revised = body.sub(POINTER, "#{MARKER} #{url}")
      return revised unless revised == body

      raise Error, 'Collapsed walkthrough pointer could not be updated.'
    end

    def wrap(body, url)
      summary = "<summary>Walkthrough for commit `#{WalkthroughText.revision(body)&.slice(0, 7)}`</summary>"
      archived = body.rstrip
      "#{MARKER} #{url}\n\n<details>\n#{summary}\n\n#{archived}\n\n</details>\n"
    end

    def replace_review(review, body, source)
      node = review['node_id']
      raise Error, 'Review has no GraphQL id.' unless node.is_a?(String) && !node.empty?

      html = @github.verify_rendering(body)
      WalkthroughText.verify_archive!(html) unless source.start_with?("#{MARKER} ")
      confirm_unchanged(review, source)
      @github.graphql(UPDATE, { id: node, body: body })
      stored = @github.review(review['id'])
      return if stored.is_a?(Hash) && stored['body'] == body

      raise Error, 'Stored review body did not match the collapsed walkthrough.'
    end

    def confirm_unchanged(review, source)
      current = @github.review(review['id'])
      return if current.is_a?(Hash) && current['body'] == source

      raise Error, 'Review body changed before collapse.'
    end

    def list_reviews
      path = "repos/#{@github.repository}/pulls/#{@github.number}/reviews"
      PublicComments::BoundedList.new(@github, max_pages: 5, label: 'Review listing').call(path)
    end

    def authenticated_login
      account = @github.api('user')['login']
      return account if account.is_a?(String) && !account.empty?

      raise Error, 'Authenticated GitHub login is unavailable.'
    end

    def review_url(id)
      "https://github.com/#{@github.repository}/pull/#{@github.number}#pullrequestreview-#{id}"
    end
  end
end
