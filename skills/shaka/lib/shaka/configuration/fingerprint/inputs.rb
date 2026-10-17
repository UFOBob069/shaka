# frozen_string_literal: true

require 'find'
require_relative '../../repository_config'
require_relative '../private_inventory'
require_relative '../private_source'
require_relative 'trusted_prompts'
require_relative '../../pr_template'

module Shaka
  module Configuration
    # Selects the inputs actually read from the candidate checkout or trusted commit.
    class FingerprintInputs
      def initialize(root:, settings:, files:, private_source:, trusted_ref:)
        @root = root
        @settings = settings
        @files = files
        @private_source = private_source
        @trusted_ref = trusted_ref
      end

      def hashes
        candidate = candidate_paths
        prompts = prompt_paths
        commands = @settings.fetch('commands').values
        return private_hashes(candidate, commands) if @private_source

        merge_trusted(@files.hashes(candidate, files_only: commands), prompts)
      rescue KeyError => e
        raise Error, "Effective settings lack #{e.key}"
      end

      private

      def candidate_paths = private_paths + @settings.fetch('commands').values

      def prompt_paths
        guidance = RepositoryConfig::ProjectGuidanceSchema.resolve(@settings)
        paths = RepositoryConfig.prompt_files(review: @settings.fetch('review'),
                                              opening: @settings.fetch('opening_check'), guidance:).map(&:last)
        paths + pr_template_paths(guidance)
      end

      # `shaka guidance pr_evidence` adds the pull request template, so the template counts as read input too.
      def pr_template_paths(guidance)
        ref = @private_source ? @private_source.ref : @trusted_ref
        return [] unless guidance['pr_evidence'] && ref

        [PrTemplate.path(root: @root, sha: ref)].compact
      end

      # Hashes each prompt where it is read: the private tree, or the default-branch commit.
      def private_hashes(candidate, commands)
        local, trusted = prompt_paths.uniq.partition { |path| PrivateInventory.private_path?(root: @root, path:) }
        hashes = @files.hashes(candidate + local, files_only: commands + local)
        return hashes if trusted.empty?

        merge_trusted(hashes, trusted, ref: @private_source.ref)
      end

      def merge_trusted(candidate, paths, ref: @trusted_ref)
        trusted = FingerprintTrustedPrompts.new(root: @root, ref:)
        trusted.hashes(paths.map { |path| @files.safe_path(path) }).each do |path, prompt_digest|
          candidate[path] = combined(candidate[path], prompt_digest)
        end
        candidate.sort.to_h
      end

      def combined(candidate_digest, prompt_digest)
        return prompt_digest unless candidate_digest

        FingerprintCanonical.digest('file-roles', { 'candidate' => candidate_digest, 'trusted' => prompt_digest })
      end

      def private_paths
        return [] unless @private_source

        recorded = @private_source.inventory.map do |entry|
          inventory_path(entry)
        end
        verify_private_inventory!(recorded)
        recorded - [@settings.dig('paths', 'policy_configuration')]
      end

      def verify_private_inventory!(recorded)
        directory = File.join(@root, PrivateInventory::DIRECTORY)
        current = Find.find(directory, ignore_error: false).map { |path| path.delete_prefix("#{@root}/") }
        raise Error, 'Private source changed since preflight; resolve it again' unless current.sort == recorded.sort

        return verify_t1_source! if @private_source.is_a?(PrivateSourceResult)

        verify_settings_snapshot!
      end

      def verify_settings_snapshot!
        before = FingerprintCanonical.normalize(@private_source.candidate_config.to_h)
        after = FingerprintCanonical.normalize(RepositoryConfig.load(root: @root).to_h)
        raise Error, 'Private settings changed since preflight; resolve them again' unless after == before
      end

      def verify_t1_source!
        fresh = PrivateSource.new(root: @root, ref: @private_source.ref).resolve
        unchanged = fresh.status == 'complete' && fresh.inventory == @private_source.inventory &&
                    fresh.candidate_config.to_h == @private_source.candidate_config.to_h
        raise Error, 'Private source changed since preflight; resolve it again' unless unchanged
      end

      def inventory_path(entry)
        path = entry[:path] if entry.is_a?(Hash)
        raise Error, 'Private source inventory lacks path' unless path.is_a?(String)

        path
      end
    end
  end
end
