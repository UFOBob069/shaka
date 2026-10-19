# frozen_string_literal: true

require_relative '../branch_name'
require_relative '../error'
require_relative 'validation'

module Shaka
  class RepositoryConfig
    # Validates the optional feature-branch layout.
    class BranchSchema
      include Validation

      # Each placeholder with a typical value, so Git can judge a name the template produces.
      SAMPLES = { 'login' => 'octocat', 'host' => 'codex', 'issue' => '123', 'description' => 'add-button' }.freeze

      def initialize(data, root:)
        @data = data
        @root = root
      end

      def validate
        mapping = mapping!(@data, 'branches')
        keys!(mapping, ['name'], [], 'branches')
        name = string!(mapping['name'], 'branches.name')
        raise Error, 'branches.name must include {issue}' unless name.include?('{issue}')

        leftover = name.scan(/\{([^{}]+)\}/).flatten - SAMPLES.keys
        raise Error, "branches.name has unknown placeholder: #{leftover.first}" unless leftover.empty?

        validate_sample(name)
      end

      private

      def validate_sample(name)
        sample = name.gsub(/\{([^{}]+)\}/) { SAMPLES.fetch(Regexp.last_match(1)) }
        BranchName.explicit!(sample, label: "branches.name (filled in as #{sample})", root: @root)
      end
    end
  end
end
