# frozen_string_literal: true

require 'shellwords'

module Shaka
  class UpdateCheck
    # The answers update-check prints: a status, the reason when the status alone is not
    # enough, and one next step.
    module Messages
      SIGNED_OUT = /gh auth login|not logged in|authentication required|HTTP 401|bad credentials/i

      private

      def current = answer('current', "This installed revision matches #{@target}.")

      def drift(head)
        answer('drift', "#{moved(head)} It matches #{@target}; run #{Shellwords.escape(@helper)} install --update " \
                        'to record it.')
      end

      def not_a_pull(head)
        answer('drift', "#{moved(head)} That is not a pull of the recorded revision from #{@target}, so " \
                        "`install --update` will stop. Return the checkout to #{recorded[0, 7]}, or keep changes " \
                        "in a separate development checkout; see #{GUIDE}.", 'not_a_pull')
      end

      def moved(head)
        "Your checkout #{@checkout} is at #{head[0, 7]}, but its installation record names #{recorded[0, 7]}."
      end

      # The checkout's commit was on the registered branch when it was last fetched, so the branch moved.
      def branch_moved(head)
        unknown('branch_moved', "#{@target} no longer contains checkout commit #{head[0, 7]}.")
      end

      def recent(count)
        answer('recent', "#{lag(count)} #{Notice::GUIDANCE}").merge('commits_behind' => count)
      end

      # GitHub reports the comparison from the installed revision, so its ahead count is how far behind this is.
      def available(ahead_by)
        count = ahead_by if ahead_by.is_a?(Integer) && ahead_by.positive?
        result = answer('available', "#{lag(count)} #{update_guidance}")
        count ? result.merge('commits_behind' => count) : result
      end

      def lag(count)
        return "Newer #{@target} commits are available." unless count

        "This installation is #{count} #{count == 1 ? 'commit' : 'commits'} behind #{@target}."
      end

      def update_guidance
        unless @checkout
          return "This is a retained copy; follow #{GUIDE} to migrate. " \
                 'Keep trial and rollback copies for active chats.'
        end

        "Finish active Shaka chats, run #{Shellwords.escape(@helper)} install --update, then start a new chat. " \
          'Continue this task with its saved helper.'
      end

      def custom
        answer('custom', "This copy differs from #{@target}: review upstream changes through #{GUIDE}. " \
                         'Keep your chosen source and local changes; do not replace it automatically.')
      end

      def development
        answer('custom', "Development source: review upstream changes through #{GUIDE}. " \
                         'Keep your chosen source and local changes; do not replace it automatically.',
               'development_source')
      end

      def unsupported_source
        answer('custom', 'Updates are checked only for a GitHub origin, branch, and full commit. ' \
                         "Review upstream changes through #{GUIDE}.", 'unsupported_source')
      end

      def request_failed(error)
        return unknown('signed_out', 'GitHub CLI is not signed in. Run `gh auth login`.') if error.match?(SIGNED_OUT)

        unknown('request_failed', "The GitHub request failed: #{first_line(error)}")
      end

      def unknown(reason, cause)
        cause = "#{cause}." unless cause.end_with?('.')
        answer('unknown', "Could not verify update availability. #{cause} Continue the task and retry " \
                          "`update-check` later; manual update guidance: #{GUIDE}.", reason)
      end

      def first_line(text)
        line = text.to_s.lines.map(&:strip).find { |entry| !entry.empty? } || 'no error output'
        line[0, 200]
      end

      def answer(status, guidance, reason = nil)
        { 'status' => status, 'guidance' => guidance, 'reason' => reason }.compact
      end
    end
  end
end
