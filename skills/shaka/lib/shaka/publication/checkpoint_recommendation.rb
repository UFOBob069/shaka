# frozen_string_literal: true

require_relative '../error'
require_relative '../post_implementation/evidence'

module Shaka
  # Reads the description's recommendation and verification verdict from the checkpoint published for its head,
  # so the headline cannot disagree with that checkpoint.
  module CheckpointRecommendation
    module_function

    def resolve(content, github)
      checkpoint = content['checkpoint']
      return content unless checkpoint.is_a?(Hash)

      supplied = checkpoint.keys & %w[recommendation verification_adequacy]
      raise Error, "Description checkpoint #{supplied.first} comes from the published checkpoint; omit it." if
        supplied.any?

      evidence = PostImplementationEvidence.new(github)
      published = { 'recommendation' => evidence.recommendation(checkpoint['head']),
                    'verification_adequacy' => evidence.adequacy(checkpoint['head']) }.compact
      published.empty? ? content : content.merge('checkpoint' => checkpoint.merge(published))
    end
  end
end
