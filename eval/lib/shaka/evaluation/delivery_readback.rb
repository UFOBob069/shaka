# frozen_string_literal: true

require 'open3'
require 'timeout'
require_relative 'delivery_review'

module Shaka
  module Evaluation
    # Run on the protected driver, with its own GitHub credentials; never mount receipts in the agent.
    class DeliveryReadback
      def initialize(repository:, number:, head:, github:, seconds: 30)
        unless valid_identity?(repository, number, head) && seconds.is_a?(Numeric) && seconds.positive? && seconds <= 30
          raise ArgumentError, 'Expected a pinned delivery PR and bounded read deadline'
        end
        unless github.is_a?(String) && github.start_with?('/')
          raise ArgumentError, 'Expected an absolute GitHub CLI path'
        end

        @expected = { 'repository' => repository, 'number' => number, 'head' => head }
        @gh = File.realpath(github)
        @seconds = seconds
      end

      def read(node_id:, review_id:, actor:)
        valid = [node_id, actor].all? { |value| value.is_a?(String) && !value.strip.empty? } &&
                review_id.is_a?(Integer) && review_id.positive?
        raise ArgumentError, 'Expected native review IDs and the declared actor' unless valid

        expected = @expected.merge('node_id' => node_id, 'review_id' => review_id.to_s, 'actor' => actor)
        request = JSON.generate({ 'query' => DeliveryReview::QUERY, 'variables' => { 'id' => node_id } })
        row = DeliveryReview.read(capture(request), expected)
        { 'review' => row, 'readback_finished_at' => Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      end

      def unchanged?(receipt)
        row = receipt.fetch('review')
        current = read(node_id: row.fetch('id'), review_id: Integer(row.fetch('fullDatabaseId'), 10),
                       actor: row.fetch('author').fetch('login'))
        current.fetch('review') == row
      rescue IOError
        false
      end

      private

      def valid_identity?(repository, number, head)
        repository.is_a?(String) && %r{\A[\w-]+/[\w.-]+\z}.match?(repository) &&
          number.is_a?(Integer) && number.positive? && /\A[0-9a-f]{40}\z/.match?(head.to_s)
      end

      def capture(request)
        argv = [@gh, 'api', '--hostname', 'github.com', 'graphql', '--input', '-']
        Open3.popen3({ 'GH_PROMPT_DISABLED' => '1' }, *argv, pgroup: true) do |input, stdout, stderr, process|
          read_process(input, stdout, stderr, process, request)
        end
      rescue SystemCallError, Timeout::Error
        raise IOError, 'Delivery review readback unavailable'
      end

      def read_process(input, stdout, stderr, process, request)
        errors = Thread.new { IO.copy_stream(stderr, File::NULL) }
        bounded_answer(input, stdout, process, request)
      ensure
        terminate(process.pid)
        errors&.join
      end

      def bounded_answer(input, stdout, process, request)
        Timeout.timeout(@seconds) { answer(input, stdout, process, request) }
      end

      def answer(input, stdout, process, request)
        input.write(request)
        input.close
        bytes = stdout.read(1_048_577).to_s
        raise IOError, 'Delivery review readback unavailable' if bytes.bytesize > 1_048_576 || !process.value.success?

        bytes
      end

      def terminate(pid)
        Process.kill('KILL', -pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
