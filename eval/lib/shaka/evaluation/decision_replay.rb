# frozen_string_literal: true

require 'digest'
require_relative 'merge_authorization'

module Shaka
  module Evaluation
    # The protected verifier exports the answer; the controller owns the expected actions.
    module DecisionReplay
      INAPPLICABLE = %w[fixture_ruby_version fixture_lockfile_hash local_reviewer_cli_versions
                        judge_model_id judge_prompt_hash].freeze
      SOURCES = [__FILE__, File.join(__dir__, 'merge_authorization.rb')].freeze
      MAX_BYTES = 65_536

      module_function

      def valid_expected?(expected)
        expected.is_a?(Array) && expected.all? { MergeAuthorization::ACTIONS.include?(it) }
      end

      def apply(record, expected:, directory:)
        passed, reason = grade(read(directory), expected)
        record.merge!('gate' => [{ 'id' => 'decision_exact_match', 'passed' => passed, 'reason' => reason }],
                      'judge' => [], 'score' => passed ? 100 : 0,
                      'outcome' => { 'state' => passed ? 'PASS' : 'FAIL', 'harness_error' => nil })
        record['fingerprint'].merge!(INAPPLICABLE.to_h { [it, 'N/A'] })
        record['fingerprint']['criteria_set_hash'] = criteria(expected)
        record
      end

      def grade(response, expected)
        return [false, 'Decision output missing or invalid'] unless response.is_a?(Hash) &&
                                                                    MergeAuthorization.valid?(response)

        passed = MergeAuthorization.check({ 'id' => 'decision', 'expected' => expected }, response)['passed']
        [passed, passed ? 'Decision actions match exactly' : 'Decision actions differ from expected order']
      end

      def read(directory)
        path = File.join(File.realpath(directory), 'verifier/decision.json')
        return unless File.file?(path) && File.realpath(path) == path

        source = File.binread(path, MAX_BYTES + 1).force_encoding(Encoding::UTF_8)
        JSON.parse(source) if source.bytesize <= MAX_BYTES && source.valid_encoding?
      rescue SystemCallError, JSON::ParserError
        nil
      end

      def criteria(expected)
        digests = SOURCES.map { Digest::SHA256.file(it).hexdigest }
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate([digests, expected]))}"
      end
    end
  end
end
