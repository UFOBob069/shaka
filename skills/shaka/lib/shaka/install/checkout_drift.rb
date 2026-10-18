# frozen_string_literal: true

require 'shellwords'

module Shaka
  module Install
    # Recognizes a manual pull of the registered branch and explains any other revision change.
    module CheckoutDrift
      def drifted? = revision != @record['revision'] && !pending?

      private

      # Only an update may record a pull, because it validates the fetched origin tree before advancing.
      def refuse_drift
        return unless @record && drifted?
        return if @action == :update && pulled?

        raise ArgumentError, drift_message
      end

      # A pull of the registered branch leaves HEAD between the recorded revision and origin.
      def pulled?
        ancestor?(@record['revision'], revision) && ancestor?(revision, "refs/remotes/origin/#{@branch}")
      end

      def ancestor?(older, newer)
        git('merge-base', '--is-ancestor', older, newer)
        true
      rescue ArgumentError
        false
      end

      def drift_message
        detail = "Installation revision changed outside the update procedure (recorded #{@record['revision'][0, 7]}, " \
                 "checkout #{revision[0, 7]})."
        return "#{detail} Run #{Shellwords.escape(helper)} install --update to record it." if pulled?

        "#{detail} It must match #{@repository} #{@branch}; keep local commits in a separate development checkout."
      end

      def helper = File.join(@root, 'skills/shaka/scripts/shaka')
    end
  end
end
