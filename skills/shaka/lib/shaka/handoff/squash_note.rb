# frozen_string_literal: true

require_relative '../github/squash_comment'
require_relative '../post_implementation/evidence'
require_relative '../public_comments/bounded_list'

module Shaka
  class Handoff
    # Finds this account's newest checkpoint or legacy standalone merge message.
    class SquashNote
      MESSAGE_HEAD = /\n#{Regexp.escape(SquashComment::SQUASH_MARK)}\n<!-- head (\h{40}) -->\n/

      def initialize(github) = @github = github

      def head
        account = @github.api('user')['login']
        ours = comments.select { |comment| comment.dig('user', 'login') == account && comment['id'].is_a?(Integer) }
        latest = ours.filter_map { |comment| message_entry(comment) }
        latest.max_by(&:first)&.last
      end

      private

      def message_entry(comment)
        body = comment['body'].to_s
        return checkpoint_entry(comment['id'], body) if body.match?(PostImplementationHistory::KEY)

        message_head = SquashComment.head(body)
        [comment['id'], message_head] if message_head
      end

      def checkpoint_entry(id, body)
        head, state = body.match(PostImplementationEvidence::ATTESTATION)&.captures
        return if state == 'opted_out'

        [id, (head if state == 'ready' && body[MESSAGE_HEAD, 1] == head)]
      end

      def comments
        path = "repos/#{@github.repository}/issues/#{@github.number}/comments"
        PublicComments::BoundedList.new(@github, max_pages: SquashComment::COMMENT_PAGES, label: 'Comment listing')
                                   .call(path)
      end
    end
  end
end
