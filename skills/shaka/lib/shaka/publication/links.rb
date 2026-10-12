# frozen_string_literal: true

require 'uri'
require_relative '../error'
require_relative 'text'

module Shaka
  # Renders the links a reader needs before any description section.
  module PublicationLinks
    WALKTHROUGH_URL = %r{\Ahttps://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/\d+#pullrequestreview-\d+\z}
    POST_IMPLEMENTATION_URL = %r{\Ahttps://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/\d+#issuecomment-\d+\z}
    UNPUBLISHED = '_Not published yet._'
    CREDIT = '_PR prepared with [Shaka](https://shaka.shakacode.com/)._'

    module_function

    def checkpoint(content, head:)
      return [] unless content.key?('checkpoint')

      checkpoint = content['checkpoint']
      raise Error, 'Description checkpoint must be an object.' unless checkpoint.is_a?(Hash)
      raise Error, 'Description checkpoint is not for the current PR head.' unless
        head && checkpoint['head'] == head

      status = PublicationText.summary_text(checkpoint['status'], 'checkpoint status')
      action = PublicationText.summary_text(checkpoint['next_action'], 'checkpoint next_action')
      ['## Checkpoint', "**Status:** #{status}", "**Recommended next action:** #{action}", "Head: `#{head}`"]
    end

    # Keep both review surfaces together before an optional deployment preview.
    def top(content, attribution)
      reviews = "#{walkthrough(content['walkthrough'])} · #{post_implementation(content['post_implementation'])}"
      preview = deployment(content['deployment'])
      [(CREDIT if attribution), preview ? "#{reviews} · #{preview}" : reviews].compact
    end

    def post_implementation(url)
      return "Checkpoint: #{UNPUBLISHED}" if url.nil? || (url.is_a?(String) && url.strip.empty?)

      url = PublicationText.single_line(url.is_a?(String) ? url.strip : url, 'post_implementation')
      unless url.match?(POST_IMPLEMENTATION_URL)
        raise Error, 'Publication post_implementation must be a GitHub pull request comment URL.'
      end

      "[Checkpoint](#{url})"
    end

    # Required so a deployable repository cannot silently omit its preview; `none` opts out.
    def deployment(url)
      url = PublicationText.single_line(url.is_a?(String) ? url.strip : url, 'deployment')
      return if url == 'none'
      raise Error, 'Publication deployment must be an https URL or none.' unless https_url?(url)

      # Angle brackets keep a `)` in the URL from ending the Markdown link early.
      "[Deployment](<#{url}>)"
    end

    def https_url?(url)
      uri = URI.parse(url)
      # Userinfo would publish credentials in a public PR body.
      uri.is_a?(URI::HTTPS) && !uri.host.to_s.empty? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
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
