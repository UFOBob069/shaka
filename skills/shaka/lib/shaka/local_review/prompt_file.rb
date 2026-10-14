# frozen_string_literal: true

require 'rbconfig'
require 'tempfile'
require_relative '../configuration'
require_relative '../reviewer_settings'
require_relative 'settings_source'

module Shaka
  # Reads the repository's review instructions from the same trusted commit as its criteria.
  module LocalReviewPromptFile
    include LocalReviewSettingsSource

    private

    def review_instructions
      script = File.expand_path('../../../scripts/shaka.rb', __dir__)
      with_prompt_arguments do |arguments|
        # The same isolation as scripts/shaka: a project's RUBYOPT and gems stay out of Shaka's Ruby.
        capture(RbConfig.ruby, '--disable-gems', '--disable-rubyopt', script, 'review-prompt', '--head', head,
                '--base', @options[:base], '--reviewer', reviewer, '--effort', effort, *arguments)
      end
    end

    # Yields the `review-prompt` arguments that select the instructions for this reviewer.
    def with_prompt_arguments
      text = trusted_prompt_text
      return yield([]) unless text

      Tempfile.create(['shaka-review-instructions-', '.md']) do |file|
        file.write(text)
        file.close
        yield ['--prompt-file', file.path]
      end
    end

    # Effective model and effort apply where the task named none.
    def apply_trusted_settings!
      agent = reviewer_settings(effective_review || {})
      return unless agent

      schema = RepositoryConfig::ReviewSchema
      { model: [schema::MODEL, :model_name!], effort: [schema::EFFORT, :effort_level!] }
        .each do |option, (key, check)|
          next if @options[option] || !agent.key?(key)

          # This read skips the schema, so a bad value must fail here as setup, not later in the CLI.
          schema.public_send(check, agent[key], "review.local_review_agents #{key}")
          @options[option] = agent[key]
        end
    end

    def apply_reviewer_settings!
      apply_trusted_settings!
      validate_model!
      @config_notices = ReviewerSettings.notices(reviewer, model: @options[:model], effort: @options[:effort])
      ReviewerSettings.refuse!(@config_notices)
    end

    def trusted_prompt_text
      review = effective_review
      return unless review

      path = configured_prompt_path(review)
      path && configured_prompt(path, 'review prompt_file')
    end

    # Individual setup keeps its own instructions in its untracked settings directory. Any other
    # path is read at the settings commit, so a branch cannot supply its own instructions.
    def configured_prompt(path, label)
      @private_prompt = individual_prompt?(path)
      return Configuration.private_prompt(root:, path:, label:) if @private_prompt

      access = { executable: git_executable, capture: method(:capture), resolver: method(:bounded_git) }
      Configuration.prompt_at_commit(root:, ref: settings_ref, path:, git_access: access)
    end

    def individual_prompt?(path)
      @individual_review && Configuration::PrivateInventory.private_path?(root:, path:)
    end

    # Runs the vetted Git under the review timeout, for this module and TrustedPathResolver.
    def bounded_git(*arguments)
      timeout = @options.fetch(:timeout_seconds)
      result = LocalReviewProcess.capture([git_executable, *arguments], stdin_data: nil, chdir: root, timeout:)
      status = result.last
      raise Shaka::Error, "git timed out after #{timeout}s" unless status
      raise Shaka::Error, 'git output drain timed out after 2s' if status.is_a?(LocalReviewProcess::DrainTimeout)

      result
    end

    # A reviewer's own file wins over the repository-wide one.
    def configured_prompt_path(review)
      prompt_file = RepositoryConfig::ReviewSchema::PROMPT_FILE
      agent = reviewer_settings(review)
      owner, path = agent&.key?(prompt_file) ? ["#{reviewer} ", agent[prompt_file]] : ['review.', review[prompt_file]]
      return if path.nil?
      raise Shaka::Error, "review #{prompt_file} must be a repository path" unless path.is_a?(String)

      @prompt_source = "#{owner}#{prompt_file} #{path}"
      path
    end

    def reviewer_settings(review)
      agents = Array(review[RepositoryConfig::ReviewSchema::LOCAL_REVIEW_AGENTS]).grep(Hash)
      agents.find { |entry| entry.values_at(*ReviewerSelection::IDENTITY).join('/').downcase == reviewer }
    end

    # Names the instructions the reviewer received, for the published review summary.
    def prompt_source
      return 'Local settings preview (private source)' if @prompt_source && settings_ref != @options[:criteria_ref]
      return 'Individual settings (private source)' if @private_prompt

      @prompt_source || 'Shaka default'
    end
  end
end
