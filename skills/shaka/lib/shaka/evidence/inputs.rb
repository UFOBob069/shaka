# frozen_string_literal: true

require_relative '../configuration'
require_relative '../configuration/fingerprint'
require_relative '../doctor/installation_identity'
require_relative 'public_settings'

module Shaka
  module Evidence
    # Resolve the same private or trusted configuration used by an operation.
    class Inputs
      def self.capture(root:, ref:, repository:, task_overrides: {})
        config, selected, kind = resolve_source(root, ref)
        installation = Doctor::InstallationIdentity.read
        fingerprint = Configuration::Fingerprint.build(
          root:, effective_settings: config.to_h.merge('task_overrides' => task_overrides), repository:,
          installation:, **selected
        )
        snapshot = PublicSettings.capture(config:, kind:, ref:, task_overrides:, installation:)
        [config, fingerprint.to_h, kind, snapshot]
      end

      def self.resolve_source(root, ref)
        Configuration.resolve_source(root:, ref:)
      end
    end
  end
end
