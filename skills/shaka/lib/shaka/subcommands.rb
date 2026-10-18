# frozen_string_literal: true

require_relative 'checkpoint'
require_relative 'claim'
require_relative 'doctor'
require_relative 'enforcement'
require_relative 'evidence/command'
require_relative 'guidance'
require_relative 'issue_create'
require_relative 'local_review'
require_relative 'post_implementation'
require_relative 'prefix'
require_relative 'recommendation'
require_relative 'repos'
require_relative 'review_prompt'
require_relative 'reviewer'
require_relative 'seam'
require_relative 'trial/command'
require_relative 'update_check'
require_relative 'usage/usage'
require_relative 'work'
require_relative 'workflow'

module Shaka
  # Commands that parse their own arguments, with the operations each takes as its second word.
  # The helper dispatches through this table and lists it in its usage banner.
  module Subcommands
    Entry = Data.define(:operations, :run)

    def self.entry(operations = [], &run) = Entry.new(operations:, run:)

    TABLE = {
      'checkpoint' => entry { |arguments| Checkpoint.run(arguments) },
      'claim' => entry { |arguments| Claim.run(arguments) },
      'doctor' => entry { |arguments| Doctor.run(arguments) },
      'enforcement' => entry { |arguments| Enforcement.run(arguments) },
      'evidence' => entry(Evidence::Command::ACTIONS.keys) { |arguments| Evidence::Command.run(arguments) },
      'guidance' => entry { |arguments| Guidance.run(arguments) },
      'install' => entry do |arguments|
        require_relative 'install/command'
        Install::Command.new(File.expand_path('../../../..', __dir__), program: 'shaka install').run(arguments)
      end,
      'issue-create' => entry { |arguments| IssueCreate.run(arguments) },
      'post-implementation' => entry(PostImplementation::ACTIONS) { |arguments| PostImplementation.run(arguments) },
      'prefix' => entry { |arguments| Prefix.run(arguments) },
      'recommendation' => entry { |arguments| Recommendation.run(arguments) },
      'repos' => entry(Repos::OPERATIONS) { |arguments| Repos.run(arguments) },
      'review' => entry(LocalReview::ACTIONS) { |arguments| LocalReview.run(arguments) },
      'review-prompt' => entry { |arguments| ReviewPrompt.run(arguments) },
      'reviewer' => entry { |arguments| Reviewer.run(arguments) },
      'seam' => entry(Seam::OPERATIONS) { |arguments| Seam.run(arguments) },
      'trial' => entry(Trial::Command::ACTIONS) { |arguments| Trial::Command.run(arguments) },
      'update-check' => entry { |arguments| UpdateCheck.run(arguments) },
      'usage' => entry { |arguments| Usage.run(arguments) },
      'work' => entry { |arguments| Work.run(arguments) },
      'workflow' => entry { |arguments| Workflow.run(arguments) }
    }.freeze

    # One banner line per command, naming its operations.
    def self.usage_lines
      TABLE.map { |name, entry| "shaka #{name} #{entry.operations.join('|')}".rstrip }
    end
  end
end
