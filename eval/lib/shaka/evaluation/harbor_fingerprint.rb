# frozen_string_literal: true

require_relative 'run_record'
require_relative 'skill_snapshot'

module Shaka
  module Evaluation
    # Native observations win; fixture and judging evidence belongs to the trusted operator.
    module HarborFingerprint
      FIELDS = JSON.parse(File.read(RunRecord::PATH)).dig('$defs', 'fingerprint', 'required').freeze
      OPERATOR = %w[machine_alias fixture_ruby_version fixture_lockfile_hash local_reviewer_cli_versions
                    judge_model_id judge_prompt_hash criteria_set_hash].freeze
      PACKAGE = %w[skill_package_digest skill_commit skill_modified workflow_hash enforcement_hash].freeze
      MODEL = %w[provider configured_model routed_model effort].freeze
      CLAUDE_EVENTS = %w[user assistant].freeze
      LOCKFILE = File.expand_path('../../../../Gemfile.lock', __dir__)

      module_function

      def valid_evidence?(evidence)
        return false unless evidence.is_a?(Hash) && (evidence.keys - OPERATOR).empty?

        fields = FIELDS.to_h { [it, 'UNKNOWN'] }.merge(evidence)
        RunRecord::SCHEMA.errors(fields, { '$ref' => '#/$defs/fingerprint' }).empty?
      end

      def read(task:, host:, capture:, evidence:)
        fields = operator_fields(evidence)
        package = capture.fetch('package')
        fields.merge!(package.slice(*PACKAGE)) if locked?(capture['lock'], package)
        fields.merge!(model(capture, host)).merge!(container(capture.fetch('environment')))
        fields.merge(native(task, host, capture))
      end

      def native(task, host, capture)
        { 'host_cli' => host, 'host_cli_version' => version(host, capture.fetch('sessions')),
          'runner_ruby_version' => RUBY_VERSION, 'runner_lockfile_hash' => lockfile,
          'task_bank_version' => task.fetch('bank_version'),
          'pinned_actions' => 'N/A', 'hosted_reviewer' => 'N/A',
          'execution_framework' => { 'name' => 'Harbor', 'version' => HarborRuntime::VERSION,
                                     'environment_digest' => capture.dig('environment', 'digest') } }
      end

      def machine_alias
        value = ENV.fetch('SHAKA_MACHINE_ALIAS', 'UNKNOWN')
        value.strip.empty? ? 'UNKNOWN' : value
      end

      def operator_fields(evidence)
        FIELDS.to_h { [it, 'UNKNOWN'] }.merge('machine_alias' => machine_alias).merge(evidence.slice(*OPERATOR))
      end

      def locked?(lock, package)
        skills = lock && lock['skills']
        skills.is_a?(Array) && skills.one? && package.key?('harbor_digest') &&
          skills.first.is_a?(Hash) && skills.first['source'] == package['source'] &&
          skills.first['digest'] == package['harbor_digest']
      end

      def model(capture, host)
        rows = capture.fetch('usage').fetch('models')
        settings = launch_settings(capture['lock'], host)
        MODEL.to_h do |key|
          values = rows.map { it.fetch(key) }
          values = [settings.fetch(key, 'UNKNOWN')] if values.all? { it == 'UNKNOWN' }
          [key, unanimous(values)]
        end
      end

      def launch_settings(lock, host)
        agent = lock && lock['agent']
        return {} unless agent.is_a?(Hash) && agent['name'] == host

        { 'configured_model' => agent['model_name']&.split('/', 2)&.last,
          'effort' => agent['kwargs'].is_a?(Hash) ? agent['kwargs']['reasoning_effort'] : nil }
      end

      def unanimous(values)
        values = values.uniq
        values.one? && values.first.is_a?(String) && !values.first.strip.empty? ? values.first : 'UNKNOWN'
      end

      def container(environment)
        rows = environment.dig('manifest', 'containers') if environment['manifest'].is_a?(Hash)
        agent = rows&.find { it['role'] == 'agent' && it['service'] == 'main' }
        return {} unless agent

        { 'container_image_digest' => agent.fetch('image'),
          'cpu_limit' => agent.dig('controls', 'NanoCpus').fdiv(1_000_000_000),
          'memory_limit_bytes' => agent.dig('controls', 'Memory') }
      end

      def version(host, sessions)
        values = sessions.flat_map do |file|
          File.foreach(file).filter_map { native_version(host, JSON.parse(it)) }
        end
        unanimous(values)
      rescue SystemCallError, JSON::ParserError, TypeError, NoMethodError
        'UNKNOWN'
      end

      def native_version(host, row)
        if host == 'codex' && row['type'] == 'session_meta'
          row.dig('payload', 'cli_version') || 'UNKNOWN'
        elsif host == 'claude-code' && CLAUDE_EVENTS.include?(row['type'])
          row['version'] || 'UNKNOWN'
        end
      end

      def lockfile
        "sha256:#{Digest::SHA256.file(LOCKFILE).hexdigest}"
      rescue SystemCallError
        'UNKNOWN'
      end
    end
  end
end
