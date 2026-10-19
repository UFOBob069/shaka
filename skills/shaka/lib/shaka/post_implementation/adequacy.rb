# frozen_string_literal: true

require_relative 'evidence'

module Shaka
  # A separate judgment from the verdict: whether the description's checks prove what its intent rests on.
  module PostImplementationAdequacy
    module_function

    def render(adequacy)
      "**Verification:** #{adequacy.fetch('verdict').capitalize}.\n\n" \
        "- Weakest claim: #{adequacy.fetch('weakest_claim')}\n- Next check: #{adequacy.fetch('next_check')}"
    end

    # Lets merge and the description read the verdict without trusting free text.
    def marker(adequacy) = adequacy && PostImplementationEvidence.adequacy(adequacy.fetch('verdict'))
  end
end
