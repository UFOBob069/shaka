# frozen_string_literal: true

require_relative '../error'
require_relative 'human_comment_rows'
require_relative 'managed_region'

module Shaka
  # Lists what people wrote on a pull request ahead of the agent's own sections, so their comments
  # are not lost among agent posts. The rows come from the `shaka comments` result; the agent adds
  # only a one-line summary of each comment too long to repeat.
  class HumanComments
    # `shaka description --comments PATH` puts that result under this content key.
    KEY = 'human_comments'
    HEADING = 'Human comments'
    OPEN_MARK = '<!-- shaka:human-comments -->'
    CLOSE_MARK = '<!-- /shaka:human-comments -->'
    BLOCK = /#{Regexp.escape(OPEN_MARK)}.*?#{Regexp.escape(CLOSE_MARK)}/m
    HEADER = "| From | Said | Response | Status |\n| --- | --- | --- | --- |"
    SUMMARIES = HumanCommentRows::SUMMARIES
    # The count line names the commit the comments were read at, so a carried list shows its age.
    STAMP = /· read at `(\h{7})`$/

    # A walkthrough is rendered without its pull request and keeps its own sections. settings
    # carries the repository's choice to show the list and how many rows it may hold.
    def self.for(content, pull, settings)
      return [] unless pull

      refuse_heading(content['sections'])
      return [] unless settings.human_comments?

      packet = content[KEY]
      packet.nil? ? carried(pull) : new(packet, pull, summaries(content[SUMMARIES]), settings.human_comment_rows).blocks
    end

    def self.summaries(given)
      return {} if given.nil?
      return given.transform_values(&:strip) if given.is_a?(Hash) && given.keys.all?(String) &&
                                                given.values.all? { |text| CommentExcerpt.summary?(text) }

      raise Error, "Publication #{SUMMARIES} must map each comment URL to one line of at most " \
                   "#{CommentExcerpt::SUMMARY_WORDS} words."
    end

    # Without a new read the published list stays. A fork author can edit the body, so a
    # fork's list is dropped instead, as its provenance history is.
    def self.carried(pull)
      head = pull.dig('head', 'repo', 'full_name')
      return [] unless head && head == pull.dig('base', 'repo', 'full_name')

      block = Publishing.managed_region(pull['body']).to_s[BLOCK]
      block ? [block, *stale_note(block[STAMP, 1], pull.dig('head', 'sha').to_s)] : []
    end

    # The note sits outside the carried block, so each publication writes it for its own head.
    def self.stale_note(read, head)
      return [] if read.nil? || head.start_with?(read)

      ["_These comments were read at `#{read}`; the pull request is now at `#{head[0, 7]}`._"]
    end

    def self.refuse_heading(sections)
      return unless sections.is_a?(Array)
      return unless sections.any? { |item| item.is_a?(Hash) && item['heading'].to_s.strip.casecmp?(HEADING) }

      raise Error, "Publication #{HEADING} is rendered from --comments, not supplied as a section."
    end

    def initialize(packet, pull, summaries, shown)
      author = pull.dig('user', 'login')
      @head = pull.dig('head', 'sha')
      @shown = shown
      check(packet, author, @head)
      prefix = "https://github.com/#{pull.dig('base', 'repo', 'full_name')}/pull/#{pull['number']}#"
      @rows, @cells = HumanCommentRows.new(HumanCommentEntries.new(packet), author:, prefix:, summaries:).call(shown)
    end

    def blocks
      return [] if @rows.empty?

      lines = @cells.map { |cells| "| #{cells.join(' | ')} |" }
      body = [counts, [HEADER, *lines].join("\n"), *omitted].join("\n\n")
      ["#{OPEN_MARK}\n## #{HEADING}\n\n#{body}\n\n#{CLOSE_MARK}"]
    end

    private

    def check(packet, author, head)
      unless packet.is_a?(Hash)
        raise Error, 'The comments file must hold the object `shaka comments --head SHA` printed.'
      end
      raise Error, 'The pull request author is unavailable for the human comment list.' unless author.is_a?(String)
      return if head && packet['head'] == head

      raise Error, "The comments were read at #{packet['head'] || 'no pull request head'}, but the pull request " \
                   "is at #{head}. Run `shaka comments` for that head and pass its output."
    end

    def counts
      open = @rows.count(&:open)
      "#{open.zero? ? 'None open' : "**#{open} open**"} · #{sources.join(', ')} · read at `#{@head[0, 7]}`"
    end

    def sources
      reviewed = @rows.filter_map(&:reviewer)
      unverified = @rows.count(&:unverified)
      authored = @rows.size - reviewed.size - unverified
      people = reviewed.uniq.size
      [("#{reviewed.size} from #{people} reviewer#{'s' if people > 1}" if people.positive?),
       ("#{authored} from the PR author" if authored.positive?),
       ("#{unverified} unverified" if unverified.positive?)].compact
    end

    def omitted
      more = @rows.size - @shown
      more.positive? ? ["_#{more} more not shown; open comments come first._"] : []
    end
  end
end
