# frozen_string_literal: true

require 'uri'
require_relative '../error'
require_relative '../post_implementation_report'
require_relative 'text'

module Shaka
  # Renders the links a reader needs before any description section.
  module PublicationLinks
    WALKTHROUGH_URL = %r{\Ahttps://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/\d+#pullrequestreview-\d+\z}
    POST_IMPLEMENTATION_URL = %r{\Ahttps://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/\d+#issuecomment-\d+\z}
    REVIEW_URL = POST_IMPLEMENTATION_URL
    UNPUBLISHED = '_Not published yet._'
    CREDIT = '_PR prepared with [Shaka](https://shaka.shakacode.com/)._'

    module_function

    # The first line is the decision a maintainer acts on, beside the evidence links that support it.
    # Open decisions come first while they last, even over a Merge checkpoint, and take the label's place.
    # The head check keeps a stale recommendation off the page, so the text need not name the commit.
    def lead(content, pull, decisions)
      links = links(content, pull)
      return [*decisions, links] unless content.key?('checkpoint')

      checkpoint = current_checkpoint(content['checkpoint'], pull)
      label = recommendation_label(checkpoint['recommendation'])
      [*decisions, decisions.any? ? links : "#{label} · #{links}", *next_action(checkpoint['next_action'])]
    end

    def current_checkpoint(checkpoint, pull)
      head = pull&.dig('head', 'sha')
      raise Error, 'Description checkpoint must be an object.' unless checkpoint.is_a?(Hash)
      raise Error, 'Description checkpoint is not for the current PR head.' unless
        head && checkpoint['head'] == head

      checkpoint
    end

    # Without a recommendation for this head, such as while the checkpoint is pending or failed, the label says so.
    def recommendation_label(recommendation)
      recommendations = PostImplementationReport::RECOMMENDATIONS
      unless recommendation.nil? || recommendations.include?(recommendation)
        raise Error, "Description checkpoint recommendation must be one of: #{recommendations.join(', ')}."
      end

      recommendation ? "**Recommendation: #{recommendation}**" : '**No recommendation yet**'
    end

    # Optional, because a Merge recommendation already says what happens next; the line adds a dependency or approval.
    def next_action(action)
      return [] if action.nil? || (action.is_a?(String) && action.strip.empty?)

      ["**Next:** #{PublicationText.summary_text(action, 'checkpoint next_action')}"]
    end

    # Keep both review surfaces together before an optional deployment preview.
    def links(content, pull)
      reviews = [walkthrough(content['walkthrough']), review(content['review']),
                 post_implementation(content['post_implementation'])].compact.join(' · ')
      preview = deployment(content['deployment']) ||
                deployment_not_found(content['deployment_not_found_for'], pull&.dig('head', 'sha'))
      preview ? "#{reviews} · #{preview}" : reviews
    end

    # The credit closes the description so it never sits between the decision and its evidence.
    def credit(settings) = settings.attribution? ? [CREDIT] : []

    def post_implementation(url)
      return "Checkpoint: #{UNPUBLISHED}" if url.nil? || (url.is_a?(String) && url.strip.empty?)

      url = PublicationText.single_line(url.is_a?(String) ? url.strip : url, 'post_implementation')
      unless url.match?(POST_IMPLEMENTATION_URL)
        raise Error, 'Publication post_implementation must be a GitHub pull request comment URL.'
      end

      "[Checkpoint](#{url})"
    end

    # Optional: the detailed local review, for a reader who wants every finding and its disposition.
    def review(url)
      return if url.nil?

      url = PublicationText.single_line(url.is_a?(String) ? url.strip : url, 'review')
      raise Error, 'Publication review must be a GitHub pull request comment URL.' unless url.match?(REVIEW_URL)

      "[Code Review](#{url})"
    end

    # Required so a deployable repository cannot silently omit its preview; `none` opts out.
    def deployment(url)
      url = PublicationText.single_line(url.is_a?(String) ? url.strip : url, 'deployment')
      return if url == 'none'
      raise Error, 'Publication deployment must be an https URL or none.' unless https_url?(url)

      # Angle brackets keep a `)` in the URL from ending the Markdown link early.
      "[Deployment](<#{url}>)"
    end

    # `auto` found nothing for this head; saying so keeps a premature lookup from reading as no deployment.
    # The helper sets the looked-up head itself, so a carried-over value for another head is refused.
    def deployment_not_found(looked_up, head)
      return if looked_up.nil?
      raise Error, 'Publication deployment_not_found_for must be a full commit SHA.' unless
        looked_up.is_a?(String) && looked_up.match?(/\A\h{40}\z/)
      raise Error, 'The deployment lookup is not for the current PR head; publish the description again.' if
        head && looked_up != head

      "Deployment: none found for `#{looked_up[0, 7]}`"
    end

    def https_url?(url)
      uri = URI.parse(url)
      # Userinfo would publish credentials in a public PR body.
      uri.is_a?(URI::HTTPS) && !uri.host.to_s.empty? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end

    # Without a repository there is no link to carry the full SHA, so the footer keeps it visible.
    def walkthrough_footer(head, repository)
      raise Error, 'Walkthrough requires the full commit SHA it explains.' unless head.to_s.match?(/\A[0-9a-f]{40}\z/)

      commit = repository ? PublicationText.commit(head, repository) : "`#{head}`"
      "_Walkthrough for commit #{commit}. This is a COMMENT, not an approval._"
    end

    def walkthrough(url)
      return UNPUBLISHED if url.nil? || (url.is_a?(String) && url.strip.empty?)

      url = PublicationText.single_line(url.is_a?(String) ? url.strip : url, 'walkthrough')
      unless url.match?(WALKTHROUGH_URL)
        raise Error, 'Publication walkthrough must be a GitHub pull request review URL.'
      end

      "[Code Walkthrough](#{url})"
    end
  end
end
