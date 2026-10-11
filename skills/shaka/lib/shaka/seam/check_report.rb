# frozen_string_literal: true

require 'json'

module Shaka
  class Seam
    # Labels seam-check JSON so candidate output cannot be cited as trusted policy.
    class CheckReport
      LOCAL_MODE = 'local/candidate'
      TRUSTED_MODE = 'trusted/ref'
      IMPLICIT_DIAGNOSTIC =
        'this check is local/candidate; it grants no policy or merge authority. ' \
        'Pass --local to make that explicit, or --ref SHA for trusted policy.'

      def self.local(config)
        new(config:, mode: LOCAL_MODE)
      end

      def self.trusted(config, ref:)
        new(config:, mode: TRUSTED_MODE, ref:)
      end

      def self.from_ref(root:, ref:)
        config = TrustedConfigSource.from_ref(root:, ref:)
        mode = Configuration::SettingsPreview.ref(root:) ? 'preview/local' : TRUSTED_MODE
        new(config:, mode:, ref:)
      end

      def self.private_settings(root:, ref:)
        raise Error, '--ref is required for private check' unless ref

        source = Configuration.private_source(root:, ref:)
        raise Error, "Private settings unavailable (#{source.status}): #{source.blockers.join('; ')}" unless
          source.status == 'complete'

        new(config: source.candidate_config, mode: source.mode, ref: source.ref)
      end

      def self.emit(payload)
        puts JSON.pretty_generate(payload)
        0
      end

      def initialize(config:, mode:, ref: nil)
        @config = config
        @mode = mode
        @ref = ref
      end

      def to_h
        @config.to_h.merge('validation' => validation)
      end

      private

      def validation
        payload = {
          'mode' => @mode,
          'grants_policy' => policy?,
          'grants_merge_authority' => false
        }
        return payload.merge('ref' => @ref, 'trusted_source' => 'absent') if @mode == 'private/local'
        return payload unless policy?

        payload.merge('ref' => @ref, 'sha' => @config.sha)
      end

      def policy? = [TRUSTED_MODE, 'preview/local'].include?(@mode)
    end
  end
end
