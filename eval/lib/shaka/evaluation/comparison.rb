# frozen_string_literal: true

require_relative 'run_record'

module Shaka
  module Evaluation
    # Comparability only: quality, statistical confidence, and release readiness are separate.
    module Comparison
      SKILL = %w[skill_package_digest skill_commit skill_modified workflow_hash enforcement_hash].freeze
      MODEL = %w[configured_model routed_model].freeze
      AXES = { 'skill' => SKILL, 'model' => MODEL, 'provider' => %w[provider], 'effort' => %w[effort],
               'tier' => %w[host_cli host_cli_version provider configured_model routed_model effort] }.freeze
      COMMON = (SKILL + %w[host_cli host_cli_version provider configured_model routed_model effort machine_alias
                           runner_ruby_version runner_lockfile_hash rate_card_hash task_bank_version]).freeze
      REQUIRED = (COMMON - %w[workflow_hash enforcement_hash]).freeze

      module_function

      def check(baseline, candidate, axis:)
        return result('refused', 'UNKNOWN', 'invalid_axis') unless AXES.key?(axis)
        return result('refused', axis, 'invalid_records') unless [baseline, candidate].all? { valid?(it) }
        return result('refused', axis, 'repeated_trial') if repeated_trial?(baseline + candidate)

        arms = [baseline, candidate].map { it.group_by { |record| record.dig('task', 'id') } }
        return result('refused', axis, 'unmatched_tasks') unless matched?(arms)

        compare(arms, axis)
      end

      def valid?(records)
        records.is_a?(Array) && !records.empty? && records.all? { RunRecord.errors(it).empty? }
      end

      def repeated_trial?(records)
        ids = records.map { it.fetch('trial_id') }
        ids.uniq.length != ids.length
      end

      def matched?(arms)
        a, b = arms
        a.keys.sort == b.keys.sort && a.all? do |id, records|
          records.length == b.fetch(id).length &&
            (records + b.fetch(id)).all? { it.fetch('task') == records.first.fetch('task') }
        end
      end

      def compare(arms, axis)
        changed = differences(arms)
        unstable = instability(arms)
        missing = provisional_fields(arms)
        mismatches = (changed - AXES.fetch(axis)) | unstable
        status = missing.empty? ? 'eligible' : 'provisional'
        status = 'refused' unless mismatches.empty?
        result(status, axis, status == 'refused' ? 'fingerprint_mismatch' : 'fingerprints_checked').merge(
          'differing_fields' => changed, 'mismatches' => mismatches.sort, 'provisional_fields' => missing,
          'suggested_axis' => axis == 'provider' && changed.intersect?(MODEL) ? 'tier' : nil
        )
      end

      def differences(arms)
        a, b = arms
        a.flat_map do |id, records|
          left = records.first.fetch('fingerprint')
          right = b.fetch(id).first.fetch('fingerprint')
          left.keys.reject { left[it] == right[it] }
        end.uniq.sort
      end

      def instability(arms)
        arms.flat_map do |arm|
          groups = arm.values.map { it.map { |record| record.fetch('fingerprint') } }
          unstable = groups.flat_map { unstable_fields(it, it.first.keys) }
          unstable | unstable_fields(groups.flatten, COMMON)
        end.uniq.sort
      end

      def unstable_fields(fingerprints, keys)
        keys.select { |key| fingerprints.any? { it[key] != fingerprints.first[key] } }
      end

      def provisional_fields(arms)
        arms.flat_map do |arm|
          arm.values.flatten.flat_map do |record|
            record.fetch('fingerprint').filter_map do |key, value|
              key if unknown?(value) || (value == 'N/A' && REQUIRED.include?(key))
            end
          end
        end.uniq.sort
      end

      def unknown?(value)
        return value.values.any? { unknown?(it) } if value.is_a?(Hash)
        return value.any? { unknown?(it) } if value.is_a?(Array)

        value == 'UNKNOWN'
      end

      def result(status, axis, reason)
        { 'status' => status, 'axis' => axis, 'reason' => reason }
      end
    end
  end
end
