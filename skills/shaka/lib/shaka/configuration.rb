# frozen_string_literal: true

require_relative 'configuration/paths'
require_relative 'configuration/layout'
require_relative 'repository_config'
require_relative 'trusted_config_source'
require_relative 'configuration/sources'
require_relative 'configuration/private_source'
require_relative 'configuration/generated_files'
require_relative 'configuration/settings_preview'

module Shaka
  # Supported access to repository configuration. Worktree and trusted-commit reads
  # are deliberately separate; callers cannot turn a missing trusted file into a
  # checkout fallback. Explicit operation settings resolution also accepts a complete
  # private source without granting policy. RepositoryConfig and TrustedConfigSource remain focused internals.
  module Configuration
    extend Sources
    extend GeneratedFiles

    module_function

    def worktree(root:) = RepositoryConfig.load(root:)

    # ref is the caller-verified default-branch commit, not a candidate checkout ref.
    def private_source(root:, ref:) = PrivateSource.new(root:, ref:).resolve

    def trusted(root:, ref:, candidate_commands: true)
      TrustedConfigSource.load(root:, ref:, candidate_commands:)
    end

    # Explicit task selections replace the complete configuration; private fallback
    # settings apply only when the repository has no shared setup.
    def resolve_source(root:, ref:, candidate_commands: true)
      sha = resolve_commit(root:, ref:, label: 'settings ref')
      preview = SettingsPreview.ref(root:)
      return preview_source(root:, ref: sha, preview:, candidate_commands:) if preview

      standard_source(root:, ref: sha, candidate_commands:)
    end

    def preview_source(root:, ref:, preview:, candidate_commands:)
      trusted(root:, ref:, candidate_commands: false) if Layout.commit(root:, sha: ref, allow_missing: true)
      config = trusted(root:, ref: preview, candidate_commands:)
      [config, { trusted_ref: ref, preview_ref: preview }, 'preview/local']
    end
    private_class_method :preview_source

    def standard_source(root:, ref:, candidate_commands:)
      source = private_source(root:, ref:)
      if source.status == 'partial' && source.trusted_source == 'absent'
        raise Error, "Individual settings are incomplete: #{source.blockers.join('; ')}"
      end

      if source.status == 'complete'
        [source.candidate_config, { private_source: source }, 'private/local']
      else
        [trusted(root:, ref:, candidate_commands:), { trusted_ref: ref }, 'trusted/team']
      end
    end

    private_class_method :standard_source

    def opening_prompt(root:, config:, ref:)
      path = config.opening_check.fetch('prompt_file')
      if config.sha || !PrivateInventory.private_path?(root:, path:)
        return TrustedConfigSource.new(root:).opening_prompt(config, ref: config.sha || ref)
      end

      private_opening_prompt(root, path)
    end

    def private_opening_prompt(root, path)
      full = File.realpath(File.expand_path(path, root))
      unless full.start_with?("#{File.realpath(root)}/#{PrivateInventory::DIRECTORY}/")
        raise Error, 'Opening prompt must remain inside the private settings tree.'
      end

      text = nil
      error = ReviewPrompt.file_error(File.size(full)) { text = File.binread(full) }
      raise Error, "opening_check.prompt_file #{error}" if error

      text.force_encoding(Encoding::UTF_8)
    end
    private_class_method :private_opening_prompt

    def path(root, name)
      Paths.at(root, Paths::REPOSITORY_NAMES.fetch(name))
    end

    def command_path(root, name)
      Paths.at(root, Paths::COMMANDS.fetch(name.to_s))
    end

    def command_file?(root, name)
      File.file?(command_path(root, name))
    end

    def contract_entry?(root)
      !Layout.worktree(root:, allow_missing: true).nil?
    end

    def contract_matches?(root, source)
      target = path(root, :CONTRACT)
      File.file?(target) && !File.symlink?(target) && File.read(target) == source
    end

    def contract_changed?(root, source)
      target = path(root, :CONTRACT)
      File.file?(target) && File.read(target) != source
    end
  end
end
