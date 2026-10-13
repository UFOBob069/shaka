# frozen_string_literal: true

module Shaka
  # Keeps the checkpoint publisher's observed and configured identity distinct.
  module PostImplementationPublisherIdentity
    private

    def identity
      provider, family = @result.fetch('reviewer', 'UNKNOWN/UNKNOWN').split('/', 2)
      PublicationText.identity('agent' => family, 'provider' => provider,
                               'model' => headline_model, 'effort' => known(@configuration[3]))
    end

    def headline_model = known(@configuration[2]) || known(@configuration[1])&.then { |model| "#{model} (configured)" }
  end
end
