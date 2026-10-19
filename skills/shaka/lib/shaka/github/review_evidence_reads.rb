# frozen_string_literal: true

module Shaka
  class GitHub
    # The reads merge uses to find a posted local review and compare later commits with it.
    module ReviewEvidenceReads
      COMPARE_START = %r{\A(?!.*\.\.)[A-Za-z0-9_][A-Za-z0-9._/-]*\z}
      COMMIT = /\A[0-9a-f]{40}\z/

      def viewer_login
        @viewer_login ||= login!(api('user')['login'])
      rescue Error => e
        raise unless e.http_status == 403

        @viewer_login = installation_viewer
      end

      def issue_comments
        PublicComments::BoundedList.new(self, max_pages: Publishing::REPLY_PAGES, label: 'Comment listing')
                                   .call("repos/#{@repository}/issues/#{@number}/comments")
      end

      # `from` may be the PR's base branch; `to` is always a commit.
      def compare(from, to)
        raise Error, 'Expected a full commit SHA.' unless to.to_s.match?(COMMIT)
        raise Error, 'Expected a commit SHA or branch name.' unless from.to_s.match?(COMPARE_START)

        api("repos/#{@repository}/compare/#{from}...#{to}")
      end

      private

      # GitHub refuses REST /user to a GitHub App installation token but answers the GraphQL
      # viewer. REST lists that token's comments under NAME[bot], so ownership checks compare that.
      def installation_viewer
        login = login!(graphql('query { viewer { login } }')['viewer']&.[]('login'))
        "#{login.delete_suffix('[bot]')}[bot]"
      end

      def login!(login)
        return login if login.is_a?(String) && !login.empty?

        raise Error, 'GitHub did not return the authenticated account.'
      end
    end
  end
end
