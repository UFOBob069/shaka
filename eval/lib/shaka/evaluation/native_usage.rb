# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative 'usage_snapshot'
require_relative 'usage_report'

module Shaka
  module Evaluation
    # Eval-only adapter for the JSONL sessions collected by the pinned Harbor integrations.
    class NativeUsage
      CARD = 'skills/shaka/config/model-rates.yml'
      attr_reader :rate_card_hash

      def initialize(helper:, rate_root:)
        unless helper.start_with?('/') && File.executable?(helper)
          raise ArgumentError,
                'Expected an absolute installed helper'
        end

        @helper = helper
        @card = File.binread(File.join(rate_root, CARD))
        @rate_card_hash = "sha256:#{Digest::SHA256.hexdigest(@card)}"
      end

      def read(host:, files:)
        raise ArgumentError, 'Expected dedicated native sessions' unless %w[codex claude-code].include?(host) &&
                                                                         files.is_a?(Array) && !files.empty?

        capture(host, files)
      end

      private

      def capture(host, files)
        Dir.mktmpdir('shaka-eval-usage') do |directory|
          pin_card(directory)
          original, neutral, identities = UsageSnapshot.write(directory, host, files)
          UsageReport.normalize(report(directory, host, original), report(directory, host, neutral),
                                host, expected: identities.flatten.uniq.size)
        end
      rescue StandardError
        { 'models' => [], 'cache_neutral_dollars' => 'UNKNOWN', 'billed_dollars' => 'UNKNOWN' }
      end

      def pin_card(directory)
        path = File.join(directory, CARD)
        FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
        File.write(path, @card, mode: 'wx', perm: 0o600)
      end

      def report(directory, host, files)
        arguments = ['usage', '--host', host, '--all-turns', '--format', 'json', '--commit', '0' * 40,
                     '--contribution', 'implementation', '--rate-root', directory]
        output, _errors, status = Open3.capture3(@helper, *arguments, *files.flat_map { |file| ['--file', file] })
        raise IOError, 'Native reader unavailable' unless status.success?

        JSON.parse(output)
      end
    end
  end
end
