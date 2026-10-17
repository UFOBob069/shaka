# frozen_string_literal: true

require_relative '../error'
require_relative '../review_thread'
require_relative '../public_comments/threads'
require_relative 'notes'

module Shaka
  module Walkthrough
    # Resolves the note threads of a walkthrough a newer one replaced, so the diff shows only
    # current guidance. A thread with any reply stays open: Shaka posts under a person's login,
    # so a reply from this account may be that person's.
    class NoteThreads
      def initialize(github, account)
        @github = github
        @account = account
      end

      # Adds each resolved thread ID to the collapse report as it resolves, and each failure to
      # its unavailable list.
      def resolve_all(reviews, report)
        reviews.select { |review| review.dig('user', 'login') == @account }.each do |review|
          resolve(review) { |id| report['resolved_notes'] << id }
        rescue Error => e
          report['unavailable'] << "Review #{review['id']} notes: #{e.message}"
        end
      end

      # Yields the ID of each thread it resolves.
      def resolve(review)
        roots = note_roots(review)
        return if roots.empty?

        index = threads
        roots.filter_map { |id| index[id] }.uniq.select { |thread| unanswered?(thread) }.each do |thread|
          yield mutate(thread['thread_id'])
        end
      end

      private

      def note_roots(review)
        path = "repos/#{@github.repository}/pulls/#{@github.number}/reviews/#{review['id']}/comments?per_page=100"
        @github.api_list(path).filter_map do |comment|
          comment['id'] if comment['in_reply_to_id'].nil? && comment.dig('user', 'login') == @account &&
                           comment['body'].to_s.start_with?(Notes::MARKER)
        end
      end

      def threads
        @reader ||= PublicComments::Threads.new(@github)
        @threads ||= @reader.call.last
      end

      def unanswered?(thread)
        id = thread['thread_id']
        return false if thread['is_resolved'] || @reader.truncated.include?(id) || @reader.anonymous.include?(id)

        @reader.authors[id] == [@account]
      end

      def mutate(id)
        resolved = @github.graphql(ReviewThread::MUTATION, id:).dig('resolveReviewThread', 'thread', 'isResolved')
        raise Error, "GitHub did not resolve walkthrough note thread #{id}." unless resolved == true

        id
      end
    end
  end
end
