# frozen_string_literal: true

require_relative '../error'
require_relative '../post_implementation/evidence'

module Shaka
  # Reads the description's recommendation from the checkpoint published for its head,
  # so the headline cannot disagree with that checkpoint.
  module CheckpointRecommendation
    module_function

    def resolve(content, github)
      checkpoint = content['checkpoint']
      return content unless checkpoint.is_a?(Hash)
      if checkpoint.key?('recommendation')
        raise Error, 'Description checkpoint recommendation comes from the published checkpoint; omit it.'
      end

      published = PostImplementationEvidence.new(github).recommendation(checkpoint['head'])
      published ? content.merge('checkpoint' => checkpoint.merge('recommendation' => published)) : content
    end
  end
end
