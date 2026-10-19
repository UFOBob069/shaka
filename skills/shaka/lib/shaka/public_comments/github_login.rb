# frozen_string_literal: true

module Shaka
  module PublicComments
    # One GitHub-login shape for config and public author checks.
    module GitHubLogin
      PATTERN = /\A(?=.{1,39}\z)[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*\z/

      def self.valid(logins)
        logins.uniq.select { |login| login.is_a?(String) && login.match?(PATTERN) }
      end

      # GraphQL names a bot author NAME; REST, and so every ownership check, names it NAME[bot].
      def self.author(author)
        return unless author.is_a?(Hash) && author['login'].is_a?(String)

        login = author['login']
        author['__typename'] == 'Bot' ? "#{login.delete_suffix('[bot]')}[bot]" : login
      end
    end
  end
end
