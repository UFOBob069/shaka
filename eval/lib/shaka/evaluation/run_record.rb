# frozen_string_literal: true

require 'json'
require_relative 'schema'

module Shaka
  module Evaluation
    # Structural validity does not establish comparability or release readiness.
    module RunRecord
      PATH = File.expand_path('../../../schemas/run-record-v1.schema.json', __dir__)
      SCHEMA = Schema.new(JSON.parse(File.read(PATH)))

      module_function

      def errors(record)
        errors = SCHEMA.errors(record)
        return errors unless errors.empty?
        return [] if record.dig('task', 'bank_version') == record.dig('fingerprint', 'task_bank_version')

        ['$.task.bank_version: differs from fingerprint.task_bank_version']
      end
    end
  end
end
