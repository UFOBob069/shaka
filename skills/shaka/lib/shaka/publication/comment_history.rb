# frozen_string_literal: true

require_relative '../walkthrough/history'

module Shaka
  # Preserves this account's older generated comments in expandable history.
  class CommentHistory
    def initialize(github) = @github = github

    def collapse(published = nil)
      report = { 'collapsed' => [], 'unavailable' => [] }
      comments = history_comments(published)
      latest = latest_comment(comments)
      return report.merge('skipped' => 'No current report found; history was left intact.') unless latest

      comments.each { |comment| fold_one(comment, latest, report) if earlier?(comment, latest) }
      report
    rescue Error => e
      report['unavailable'] << e.message
      report
    end

    private

    def history_comments(published)
      @account = @github.viewer_login
      raise Error, 'Authenticated GitHub login is unavailable.' unless @account.is_a?(String) && !@account.empty?

      comments = @github.issue_comments.select { |comment| owned?(comment) }
      raise Error, 'Published history comment is absent from comment listing.' unless
        published.nil? || comments.any? { |comment| comment['id'] == published['id'] }

      comments
    end

    def owned?(comment)
      comment.dig('user', 'login') == @account && comment['body'].to_s.match?(self.class::KEY)
    end

    def latest_comment(comments) = comments.max_by { |comment| order(comment) }

    def earlier?(comment, latest) = (order(comment) <=> order(latest)) == -1

    def footer(_content) = ''

    # Earlier text the archive keeps unchanged and need not pass the escape and table checks again.
    def quoted(_source) = []

    def order(comment)
      time = WalkthroughText.submitted_at(comment.merge('submitted_at' => comment['created_at']))
      id = comment['id']
      raise Error, 'History comment has no creation time or identifier.' unless
        time && id.is_a?(Integer) && id.positive?

      [time, id]
    end

    def fold_one(comment, latest, report)
      path = "repos/#{@github.repository}/issues/comments/#{comment.fetch('id')}"
      source = fresh_body(path, latest)
      return unless source

      body = revised_body(source, latest['id'])
      return unless body && body != source

      replace(path, source, body)
      report['collapsed'] << comment['id']
    rescue Error => e
      report['unavailable'] << "Comment #{comment['id']}: #{e.message}"
    end

    def fresh_body(path, latest)
      source = @github.api(path)
      raise Error, 'History comment changed before collapse.' unless owned?(source)

      source.fetch('body') if earlier?(source, latest)
    end

    def revised_body(body, latest)
      lead, content = parts(body)
      revised = if content.start_with?("#{self.class::MARKER} ")
                  retarget(content, latest)
                else
                  wrap(content, latest)
                end
      "#{lead}#{revised}" if revised
    end

    # The lines that stay above the pointer, then the content the pointer covers.
    def parts(body)
      mark, content = body.split("\n", 2)
      identity = content.to_s[/\A🤖 [^\n]+\n\n/] || ''
      ["#{mark}\n#{identity}", content.to_s.delete_prefix(identity)]
    end

    def retarget(content, latest)
      pointer = /\A#{Regexp.escape(self.class::MARKER)} #{Regexp.escape(url_prefix)}(\d+)(?=\n|\z)/
      match = content.match(pointer) || raise(Error, 'Collapsed history comment pointer is malformed.')
      # An overlapping publication may already have linked a newer comment.
      return if keep_pointer?(match[1].to_i, latest)

      content.sub(pointer, "#{self.class::MARKER} #{url_prefix}#{latest}")
    end

    def keep_pointer?(previous, latest) = previous >= latest

    def wrap(content, latest)
      archived = content.rstrip
      "#{self.class::MARKER} #{url_prefix}#{latest}\n\n<details>\n<summary>#{self.class::SUMMARY}</summary>\n\n" \
        "#{archived}\n\n</details>\n#{footer(content)}"
    end

    def replace(path, source, body)
      verify_history_rendering(body, source)
      raise Error, 'History comment body changed before update.' unless @github.api(path)['body'] == source

      @github.api(path, method: 'PATCH', fields: { body: })
      return if @github.api(path)['body'] == body

      raise Error, 'Stored history comment body does not match the collapsed report.'
    end

    def verify_history_rendering(body, source)
      html = @github.verify_rendering(body, verbatim: quoted(source))
      return if archived?(source)

      ending = footer(source)
      footer_html = ending.empty? ? '' : @github.verify_rendering(ending)
      WalkthroughText.verify_archive!(html, footer_html:)
    end

    def archived?(source) = parts(source).last.start_with?("#{self.class::MARKER} ")

    def url_prefix = "https://github.com/#{@github.repository}/pull/#{@github.number}#issuecomment-"
  end
end
