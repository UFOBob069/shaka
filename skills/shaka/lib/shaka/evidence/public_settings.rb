# frozen_string_literal: true

require_relative '../doctor/installation_identity'
require_relative '../configuration/paths'

module Shaka
  module Evidence
    # This projection is recorded at the operation, not reconstructed for an earlier check.
    # No paths, arbitrary strings, private content, or component hashes enter it.
    module PublicSettings
      ENUMS = {
        'source' => %w[private/local trusted/team],
        'source.layout' => %w[legacy new],
        'installation.source' => %w[revision development uninstalled],
        'merge.preference' => %w[ask auto],
        'merge.private_trial_default' => %w[ask],
        'review.required' => %w[always meaningful_changes none],
        'review.ci_review_wait' => %w[none one all],
        'overrides.command' => %w[setup test validate validate_local trigger_hosted_ci],
        'overrides.effort' => %w[none minimal low medium high xhigh max ultra],
        'overrides.reviewer' => %w[anthropic/claude openai/codex xai/grok deepseek/openrouter]
      }.freeze
      BOOLEANS = %w[wip.include_locations opening_check.external_enabled pr_description.show_shaka_credit].freeze
      NUMBERS = %w[merge.limits.max_changed_files merge.limits.max_changed_lines merge.limits.max_commits
                   prose_limits.max_sentence_words prose_limits.max_paragraph_words prose_limits.max_description_words
                   prose_limits.words_per_changed_line].freeze
      REDACTED = %w[commands paths review.prompts review.ci_review_jobs merge.required_checks branches base_branch
                    overrides.arguments overrides.model local_changes defaults_changed].freeze
      FIELDS = (ENUMS.keys + BOOLEANS + NUMBERS + REDACTED +
                %w[source.revision source.configuration installation.version installation.revision]).freeze

      module_function

      def capture(config:, kind:, ref:, task_overrides:, installation: Doctor::InstallationIdentity.read)
        snapshot = setting_values(config.to_h)
        snapshot.merge!(source_values(kind, ref, config.config_path), installation_values(installation))
        task_overrides.each { |key, value| snapshot["overrides.#{key}"] = value }
        snapshot['merge.private_trial_default'] = 'ask' if kind == 'private/local'
        REDACTED.each { |field| snapshot[field] = 'REDACTED' }
        snapshot['defaults_changed'] = 'UNKNOWN'
        sanitize(snapshot)
      end

      def setting_values(values)
        (ENUMS.keys + BOOLEANS + NUMBERS).to_h { |field| [field, values.dig(*field.split('.'))] }
      end

      def source_values(kind, ref, path)
        { 'source' => kind, 'source.revision' => ref,
          'source.layout' => path == Configuration::Paths::NEW_CONTRACT ? 'new' : 'legacy',
          'source.configuration' => kind }
      end

      def installation_values(installation)
        revision = 'REDACTED'
        revision = installation.dig('source', 'revision') if
          installation.dig('source', 'repository') == 'shakacode/shaka'
        { 'installation.source' => installation.dig('source', 'kind'),
          'installation.version' => installation['version'], 'installation.revision' => revision }
      end

      def binding_reasons(snapshot, current, source_ref)
        return [] unless snapshot

        unchanged = snapshot.is_a?(Hash) && snapshot.except('source.revision') == current.except('source.revision') &&
                    snapshot['source.revision'] == source_ref
        unchanged ? [] : ['public settings snapshot differs from settings checked']
      end

      # Reapply the allowlist at publication: result JSON is data, never markup.
      def sanitize(snapshot)
        FIELDS.to_h { |field| [field, safe(field, snapshot.is_a?(Hash) ? snapshot[field] : nil)] }
      end

      VALIDATORS = {
        **ENUMS.transform_values { |values| ->(value) { values.include?(value) } },
        **BOOLEANS.to_h { |field| [field, ->(value) { [true, false].include?(value) }] },
        **NUMBERS.to_h { |field| [field, ->(value) { value.is_a?(Integer) && value.between?(0, 1_000_000) }] },
        'source.revision' => ->(value) { value.to_s.match?(/\A[0-9a-f]{40}(?:[0-9a-f]{24})?\z/) },
        'installation.revision' => ->(value) { value.to_s.match?(/\A[0-9a-f]{40}(?:[0-9a-f]{24})?\z/) },
        'source.configuration' => ->(value) { %w[ABSENT private/local trusted/team].include?(value) },
        'installation.version' => lambda do |value|
          value.to_s.match?(/\A\d+\.\d+\.\d+(?:[.-](?:pre|rc|beta|alpha)[.-]?\d+)*\z/)
        end
      }.freeze

      def safe(field, value)
        return 'UNKNOWN' if value.nil? || value == 'UNKNOWN'
        return 'REDACTED' if value == 'REDACTED' || REDACTED.include?(field)

        VALIDATORS[field]&.call(value) ? value : 'REDACTED'
      end
    end
  end
end
