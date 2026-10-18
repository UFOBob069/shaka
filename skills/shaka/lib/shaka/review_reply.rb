# frozen_string_literal: true

require_relative 'error'
require_relative 'merge_review_evidence'
require_relative 'publication/publication'
require_relative 'reviewer_selection'
require_relative 'public_comments/github_login'

module Shaka
  # Writes the opening of a reply that addresses a review.
  #
  # The author supplies comment URLs. Provider, model, and effort come from that comment's
  # attestation and round ledger, so a reply cannot name a reviewer the comment does not show.
  class ReviewReply
    # GitHub puts a hyphen before an issue-comment id and a review id, and none before a discussion id.
    HYPHENATED = %r{\Ahttps://github\.com/([\w.-]+)/([\w.-]+)/(pull|issues)/(\d+)#(issuecomment|pullrequestreview)-(\d+)\z}
    DISCUSSION = %r{\Ahttps://github\.com/([\w.-]+)/([\w.-]+)/pull/(\d+)#discussion_r(\d+)\z}

    def self.compose(content, github, publisher_note: nil) = new(content, github, publisher_note:).compose

    def initialize(content, github, publisher_note: nil)
      raise Error, 'Publication content must be an object.' unless content.is_a?(Hash)

      @content = content
      @github = github
      validate_content
      @publisher_note = publisher_note
    end

    def compose
      body = Publication.comment(@content.merge('publisher_note' => @publisher_note))
      lines = lead_lines
      return body if lines.empty?

      "#{lines.join("\n")}\n\n#{body}"
    end

    private

    def validate_content
      unsupported = @content.keys - %w[identity summary reviews]
      return if unsupported.empty?

      raise Error, "Unsupported reply content: #{unsupported.join(', ')}. " \
                   'Use identity, summary, and optional reviews; put explanations in summary.'
    end

    def lead_lines
      urls = @content['reviews']
      return [] if urls.nil?
      raise Error, 'A review reply needs each comment URL it addresses.' unless urls.is_a?(Array) && !urls.empty?

      urls.map { |url| line(url) }
    end

    def line(url)
      raise Error, 'A review reply takes a comment URL, not a typed reviewer identity.' unless url.is_a?(String)

      comment = located(url)
      Evidence.line(body: comment.fetch('body').to_s, url: url, author: comment.dig('user', 'login'))
    end

    def located(url)
      parts = parsed_url(url)
      raise Error, 'A review comment URL must point at a comment on this pull request.' unless on_pull?(parts)

      _owner, _repo, _path, _number, fragment, id = parts
      found = comments(fragment, id).find { |comment| comment.is_a?(Hash) && comment['id'].to_s == id }
      return found if found

      raise Error, 'The review comment was not found on this pull request.'
    end

    def parsed_url(url)
      if (match = url.match(HYPHENATED))
        match.captures
      elsif (match = url.match(DISCUSSION))
        owner, repo, number, id = match.captures
        [owner, repo, 'pull', number, 'discussion_r', id]
      end
    end

    def on_pull?(parts)
      return false unless parts

      owner, repo, path, number, fragment, = parts
      return false unless "#{owner}/#{repo}".casecmp?(@github.repository) && number.to_i == @github.number
      return true if path == 'pull'

      path == 'issues' && fragment == 'issuecomment'
    end

    def comments(fragment, id)
      case fragment
      when 'issuecomment' then @github.issue_comments
      when 'discussion_r' then [discussion_comment(id)]
      else [@github.review(id)]
      end
    end

    # One request by id. A list stops after its first page, so a later comment looks missing.
    def discussion_comment(id)
      comment = @github.api("repos/#{@github.repository}/pulls/comments/#{id}")
      return comment if comment.is_a?(Hash) &&
                        comment['pull_request_url'].to_s.match?(%r{/pulls/#{@github.number}\z})

      {}
    end

    # One published review comment, read back into the opening line.
    class Evidence
      # A heading or ledger cell is copied into the reply, so it cannot carry Markdown or a mention.
      HEADING = /^\#{1,6} ([A-Za-z0-9][A-Za-z0-9 ._-]*)$/
      TOKEN = /\A[A-Za-z0-9][A-Za-z0-9._+-]*\z/
      COLUMNS = %w[Commit Reviewer].freeze
      # The reviewer cell reads `PROVIDER/FAMILY<br>model MODEL<br>effort EFFORT`.
      MODEL = /\A\s*model (.*)\z/

      def self.line(body:, url:, author: nil) = new(body, url, author).line

      def initialize(body, url, author)
        @body = body
        @url = url
        @author = author
      end

      def line
        evidence = identity
        return response_line unless evidence

        provider, model, effort, sha = evidence
        short = sha ? sha[0, 7] : 'UNKNOWN'
        "Addressed the [#{heading}](#{@url}) by #{provider}/#{model} (#{effort}) on `#{short}`."
      end

      private

      # Hosted reviews and human comments do not publish Shaka's local attestation.
      # Name their GitHub author without inferring execution metadata from prose.
      def response_line
        author = @author if @author.is_a?(String) &&
                            @author.delete_suffix('[bot]').match?(PublicComments::GitHubLogin::PATTERN)
        attribution = author ? " by `#{author}`" : ''
        "Responded to the [#{heading}](#{@url})#{attribution}."
      end

      def heading
        text = @body.each_line.filter_map { |row| row.rstrip.match(HEADING)&.captures&.first }.first&.strip
        text.nil? || text.empty? ? 'review' : text
      end

      def identity
        sha, reviewer, effort, = @body.match(MergeReviewEvidence::ATTESTATION)&.captures
        parsed = parse_reviewer(reviewer)
        return unless parsed

        [token(parsed.fetch('provider')), ledger_model(sha, reviewer), token(effort), sha]
      end

      def parse_reviewer(reviewer)
        return unless reviewer

        ReviewerSelection.parse(reviewer)
      rescue Error
        nil
      end

      def ledger_model(sha, reviewer)
        row = ledger_rows.reverse.find { |cells| match_row?(cells, sha, reviewer) }
        token(row && row[:model])
      end

      def token(value)
        text = value.to_s.strip
        text.match?(TOKEN) ? text : 'UNKNOWN'
      end

      def match_row?(cells, sha, reviewer)
        cells[:commit].include?(sha[0, 7]) && cells[:reviewer].casecmp?(reviewer)
      end

      def ledger_rows
        rows = ledger_table
        return [] if rows.empty?

        indexes = rows.first.each_with_index.to_h
        rows.drop(1).filter_map { |cells| record(cells, indexes) }
      end

      # Comments published before the reviewer cell held the model carry a separate Model column.
      def record(cells, indexes)
        return if cells.all? { |cell| cell.match?(/\A:?-+:?\z/) }
        return if COLUMNS.any? { |name| cells[indexes[name]].nil? }

        reviewer, *settings = cells[indexes['Reviewer']].split('<br>')
        { commit: cells[indexes['Commit']], reviewer: reviewer.to_s.strip, model: model(cells, indexes, settings) }
      end

      def model(cells, indexes, settings)
        return cells[indexes['Model']] if indexes['Model']

        settings.filter_map { |part| part[MODEL, 1] }.first
      end

      # The round ledger is the first table with Commit and Reviewer columns; a reviewed-commits
      # table can precede it. A later table can sit inside an embedded report, so only the first counts.
      def ledger_table
        tables.find { |rows| (COLUMNS - rows.first).empty? } || []
      end

      def tables
        @body.each_line.map { |row| split_cells(row.rstrip) }.chunk_while { |row, after| row && after }
             .map(&:compact).reject(&:empty?)
      end

      def split_cells(row)
        return unless row.start_with?('|') && row.end_with?('|')

        row[1..].chomp('|').split(/(?<!\\)\|/, -1).map { |cell| unescape(cell) }
      end

      def unescape(cell) = cell.strip.gsub(/\\([\\|])/, '\1').strip
    end
  end
end
