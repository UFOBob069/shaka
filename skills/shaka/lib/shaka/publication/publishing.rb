# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative '../public_comments/bounded_list'
require_relative '../public_comments/reply_guard'
require_relative 'publication'
require_relative 'feature_guard'
require_relative 'managed_region'
require_relative 'merge_warning_region'
require_relative 'rendered_prose'

module Shaka
  # Publishes rendered Markdown, checking GitHub's own rendering before anything is written
  # and confirming the stored bytes afterwards.
  module Publishing
    VERBATIM = 'Quoted text.'
    REPLY_PAGES = 20

    # A block builds the body from the pull request it replaces, using this same read.
    def description(body: nil)
      current = pull
      existing = current['body'].to_s
      merged = check_length(merge(existing, publishable(block_given? ? yield(current) : body)))
      verify_rendering(merged)
      check_unchanged(existing, current)
      confirmed(api(pull_path, method: 'PATCH', fields: { body: merged }), merged)
    end

    # `verbatim` names quoted text the rendering check leaves to the caller; see verify_rendering.
    def reply(body:, key:, comment: nil, trust_config: nil, verbatim: [], # rubocop:disable Metrics/ParameterLists
              machine_path: PublicComments::TrustConfig::MACHINE_PATH)
      mark = reply_mark(key)
      content = "#{mark}\n#{publishable(body)}"
      target = positive_integer(comment) if comment
      pull
      existing = prepared_reply(target, mark, trust_config, machine_path)
      verify_rendering(content, verbatim:)
      confirmed(write_reply(existing, content, target), content)
    end

    # gh uploads each "PATH#ALT TEXT" attachment, rewriting a body reference to the file;
    # the REST API alone cannot upload images.
    def post_comment(body, attachments: [])
      argv = %W[gh pr comment #{@number} --repo #{@repository} --body-file -]
      capture(argv + attachments.flat_map { |attachment| ['--attach', attachment] }, input: publishable(body))
    end

    def prepared_reply(target, mark, trust_config, machine_path)
      account = viewer
      listed = replies(target)
      PublicComments::ReplyGuard.new(self, trust_config:, machine_path:).check(listed, target, account)
      listed.find { |reply| ours?(reply, mark, account) && (!target || reply['in_reply_to_id'] == target) }
    end

    # A body GitHub will not render correctly must never reach the pull request. Each `verbatim`
    # text, such as a reviewer report, is published as written, so only the text around it gets
    # the escape and table checks; the caller checks how the whole rendering keeps its structure.
    # Each text stands in for its first occurrence only, so a copy in surrounding text stays checked.
    def verify_rendering(body, verbatim: [])
      html = markdown(body)
      checked = verbatim.reject(&:empty?).reduce(body) { |text, quoted| text.sub(quoted) { VERBATIM } }
      RenderedProse.check!(checked, checked == body ? html : markdown(checked))
      html
    end

    def markdown(text)
      capture(['gh', 'api', 'markdown', '--method', 'POST', '--input', '-'],
              input: JSON.generate({ mode: 'gfm', text: text }))
    end

    private

    # Only a comment this account wrote, whose body opens with the marker, is ours to replace.
    def ours?(comment, mark, account)
      comment['body'].to_s.start_with?(mark) && comment.dig('user', 'login') == account
    end

    def viewer = @viewer ||= api('user')['login']

    # Only the marked region is ours; anything a person or another bot added stays.
    def merge(existing, body)
      managed = "#{OPEN_MARK}\n#{body}#{CLOSE_MARK}"
      return managed if existing.strip.empty?

      opens = existing.scan(OPEN_MARK).size
      closes = existing.scan(CLOSE_MARK).size
      return MergeWarningRegion.prepend(existing, managed) if opens.zero? && closes.zero?

      check_region(existing, opens, closes)
      prefix, rest = existing.split(OPEN_MARK, 2)
      "#{prefix}#{managed}#{rest.split(CLOSE_MARK, 2).last}"
    end

    # Carried usage records grow the body; GitHub would otherwise reject it with an opaque error.
    def check_length(body) = body.length <= 65_536 ? body : raise(Error, "Body exceeds GitHub's 65536-character limit.")

    # This update rewrites the whole body, so an edit that landed while it was prepared
    # would be erased. Re-reading narrows that window; it does not close it, because
    # GitHub offers no compare-and-swap for a pull request body.
    def check_unchanged(existing, original) = FeaturePublication.unchanged!(self, existing, original)

    # Rewriting an ambiguous region would delete whatever sits between the wrong markers.
    def check_region(existing, opens, closes)
      return if opens == 1 && closes == 1 && existing.index(OPEN_MARK) < existing.index(CLOSE_MARK)

      raise Error, 'The description has an ambiguous or malformed managed region; repair it before publishing.'
    end

    def write_reply(existing, content, target)
      return existing if existing && existing['body'] == content

      path = if existing
               "repos/#{@repository}/#{comments_collection(target)}/comments/#{positive_integer(existing['id'])}"
             elsif target
               "repos/#{@repository}/pulls/#{@number}/comments/#{target}/replies"
             else
               "repos/#{@repository}/issues/#{@number}/comments"
             end
      api(path, method: existing ? 'PATCH' : 'POST', fields: { body: content })
    end

    # gh has no --slurp, and --paginate concatenates pages into invalid JSON,
    # so the shared bounded reader requests one page at a time.
    def replies(target)
      path = "repos/#{@repository}/#{comments_collection(target)}/#{@number}/comments"
      PublicComments::BoundedList.new(self, max_pages: REPLY_PAGES, label: 'Comment listing').call(path)
    end

    def comments_collection(target) = target ? 'pulls' : 'issues'

    def reply_mark(key)
      raise Error, 'Expected a short reply key of letters, digits, hyphens or underscores.' unless
        key.is_a?(String) && key.match?(/\A[\w-]{1,64}\z/)

      "<!-- shaka:reply:#{key} -->"
    end

    def pull = api(pull_path)
    def pull_path = "repos/#{@repository}/pulls/#{@number}"

    def publishable(body)
      body = utf8(body)
      raise Error, 'Publication body must be nonempty.' if body.strip.empty?

      body
    end

    def confirmed(published, expected)
      raise Error, 'GitHub API response must be an object.' unless published.is_a?(Hash)
      return published if published['body'] == expected

      raise Error, 'The stored body does not match what was submitted; inspect the pull request before retrying.'
    end
  end
end
