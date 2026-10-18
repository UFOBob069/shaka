# frozen_string_literal: true

module Shaka
  class PrWatch
    # Turns a read the PR outran into the head_moved or closed wake that explains it.
    module PrChange
      private

      def pr_change_reason
        current = @github.snapshot
        return 'head_moved' if current['headRefOid'] != @head

        'closed' unless current['state'] == 'OPEN'
      end

      # The status and comment readers refuse a PR that moves or closes mid-read; that change is the wake.
      def changed_during_read(error) = pr_change_reason || raise(error)

      def seed_comments
        @seen = comment_ids(@baseline || @comments.call)
        nil
      rescue Error => e
        changed_during_read(e)
      end
    end
  end
end
