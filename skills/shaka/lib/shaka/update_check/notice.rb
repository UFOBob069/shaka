# frozen_string_literal: true

require 'time'

module Shaka
  class UpdateCheck
    # Main moves several times a day, so the update notice waits until an update is worth interrupting a chat.
    module Notice
      COMMITS = 3
      SECONDS = 24 * 60 * 60
      # The SessionStart hook's argument: report the saved answer as plain text, with no network request.
      SESSION_START = '--session-start'
      GUIDANCE = "Shaka suggests updating once it is #{COMMITS} commits or a day behind.".freeze

      # A usable count below the threshold waits unless the oldest missing commit is a day old.
      def self.wait?(ahead_by, oldest, now: Time.now)
        return false unless ahead_by.is_a?(Integer) && ahead_by.positive? && ahead_by < COMMITS

        now - Time.iso8601(oldest.to_s) < SECONDS
      rescue ArgumentError
        true
      end
    end
  end
end
