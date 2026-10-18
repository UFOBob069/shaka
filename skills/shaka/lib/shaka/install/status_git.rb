# frozen_string_literal: true

require_relative 'checkout_git'

module Shaka
  module Install
    # Git reads that answer nil or false instead of raising, so one failed read cannot hide the rest.
    module StatusGit
      include CheckoutGit

      private

      # No fsmonitor hook: a status read must not start a program the checkout's config names.
      def value(*)
        git('-c', 'core.fsmonitor=false', *)
      rescue ArgumentError
        nil
      end

      def ancestor?(older, newer)
        git('merge-base', '--is-ancestor', older, newer)
        true
      rescue ArgumentError
        false
      end

      def listed(items)
        shown = items.first(5).join(', ')
        items.size > 5 ? "#{shown}, and #{items.size - 5} more" : shown
      end
    end
  end
end
