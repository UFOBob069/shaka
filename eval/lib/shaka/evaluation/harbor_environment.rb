# frozen_string_literal: true

require 'json'
require 'digest'

module Shaka
  module Evaluation
    # Fingerprints retained Docker readbacks, never tags, environment variables or host paths.
    module HarborEnvironment
      CONTROLS = %w[NanoCpus Memory ReadonlyRootfs Init PidsLimit CapDrop CapAdd SecurityOpt].freeze
      MOUNT = %w[Destination RW Type].freeze

      module_function

      def capture(containers, name:)
        raise ArgumentError unless verifier_projects(containers, name).one?

        rows = containers.map { readback(it, name) }
        raise ArgumentError unless complete?(rows)

        manifest = canonical({ 'version' => 1, 'containers' => rows.sort_by { [it['role'], it['service']] } })
        { 'manifest' => manifest, 'digest' => "sha256:#{Digest::SHA256.hexdigest(JSON.generate(manifest))}" }
      rescue KeyError, TypeError, NoMethodError, ArgumentError
        { 'manifest' => 'UNKNOWN', 'digest' => 'UNKNOWN' }
      end

      def verifier_projects(containers, name)
        containers.map { it.fetch('Config').fetch('Labels').fetch('com.docker.compose.project') }
                  .select { it.start_with?("#{name}__verifier__") }.uniq
      end

      def readback(container, name)
        identity(container, name).merge('user' => container.fetch('Config').fetch('User'),
                                        'controls' => controls(container.fetch('HostConfig')),
                                        'mounts' => mounts(container.fetch('Mounts')))
      end

      def identity(container, name)
        labels = container.fetch('Config').fetch('Labels')
        project = labels.fetch('com.docker.compose.project')
        role = project.delete_prefix("#{name}__")
        image = container.fetch('Image')
        raise ArgumentError unless project.start_with?("#{name}__") &&
                                   role.match?(/\A(?:env|verifier__[a-z0-9_-]+)\z/) &&
                                   image.match?(/\Asha256:[0-9a-f]{64}\z/)

        { 'role' => role == 'env' ? 'agent' : 'verifier',
          'service' => labels.fetch('com.docker.compose.service'), 'image' => image }
      end

      def controls(config)
        result = CONTROLS.to_h { [it, config.fetch(it)] }
        raise ArgumentError unless valid_limits?(result)

        %w[CapDrop CapAdd SecurityOpt].each { |key| result[key] = result[key]&.sort }
        result.merge(config.slice('Sysctls', 'Tmpfs'))
      end

      def mounts(entries)
        entries.map { |entry| MOUNT.to_h { [it, entry.fetch(it)] } }
               .sort_by { [it.fetch('Destination'), it.fetch('Type')] }
      end

      def complete?(rows)
        keys = rows.map { [it.fetch('role'), it.fetch('service')] }
        keys.uniq.size == keys.size && valid_services?(keys) &&
          keys.include?(%w[agent main]) && keys.include?(%w[verifier main])
      end

      def valid_services?(keys)
        keys.all? { |_, service| service.is_a?(String) && !service.empty? }
      end

      def valid_limits?(config)
        [config['NanoCpus'], config['Memory']].all? { it.is_a?(Integer) && it >= 0 } &&
          [true, false].include?(config['ReadonlyRootfs'])
      end

      def canonical(value)
        return value.keys.sort.to_h { [it, canonical(value.fetch(it))] } if value.is_a?(Hash)
        return value.map { canonical(it) } if value.is_a?(Array)

        value
      end
    end
  end
end
