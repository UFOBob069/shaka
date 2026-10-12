# frozen_string_literal: true

require_relative '../publication/comment_history'

module Shaka
  # Keeps this account's older checkpoint comments linked to its newest execution.
  class PostImplementationHistory < CommentHistory
    MARKER = 'Superseded — read the current checkpoint:'
    LEGACY_MARKER = 'Superseded — read the current product validation:'
    KEY = /\A<!-- shaka:reply:post-implementation-[0-9a-f]{7}-[0-9a-f]{8} -->\n/
    SUMMARY = 'Earlier checkpoint'

    private

    def revised_body(body, latest)
      super(normalize(body), latest)
    end

    def archived?(source) = super(normalize(source))

    def normalize(body)
      content = body.split("\n", 2).last.to_s.sub(/\A🤖 [^\n]+\n\n/, '')
      return body unless content.start_with?(LEGACY_MARKER)

      body.sub(LEGACY_MARKER, MARKER).sub('<summary>Earlier product validation</summary>',
                                          "<summary>#{SUMMARY}</summary>")
    end
  end
end
