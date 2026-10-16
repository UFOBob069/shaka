# frozen_string_literal: true

require_relative '../defaults'
require_relative '../error'

module Shaka
  class RepositoryConfig
    # Shared by seam validation, the runner's trusted read, and ledger publication.
    module ReviewLimit
      KEY = 'local_max_rounds'
      DEFAULT = Defaults.fetch('review', KEY)

      def self.from(review)
        value = review.fetch(KEY, DEFAULT)
        return value if value.is_a?(Integer) && value.positive?

        raise Error, 'review.local_max_rounds must be a positive integer'
      end
    end
  end
end
