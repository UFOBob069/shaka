# frozen_string_literal: true

require 'tmpdir'
require_relative 'harbor_runtime'
require_relative 'harbor_environment'
require_relative 'runner'

module Shaka
  module Evaluation
    # Reserves before launching; a trusted block supplies grading and the full record.
    class HarborTrial
      def initialize(runtime:, usage:, tasks:, directory:)
        @runtime = runtime
        @usage = usage
        @tasks = tasks.transform_values { |path| File.realpath(path) }.freeze
        @directory = File.expand_path(directory)
        FileUtils.mkdir_p(@directory, mode: 0o700)
        return if File.stat(@directory).mode.nobits?(0o077)

        raise ArgumentError,
              'Expected a private new capture directory'
      end

      def run(tasks, budget:, records:, &builder)
        validate_tasks(tasks, builder)

        Dir.mktmpdir('preflight-', @directory) { |path| @runtime.preflight(path) }
        Runner.new(budget: budget, directory: records).run(tasks) do |task, id|
          capture = capture(task, id)
          account(yield(task, id, capture), capture)
        end
      end

      private

      def validate_tasks(tasks, builder)
        return if builder && tasks.is_a?(Array) && !tasks.empty? && tasks.all? { |task| planned?(task) }

        raise ArgumentError, 'Expected tier 2 tasks and a trusted record builder'
      end

      def account(record, capture)
        record['usage'] = capture.fetch('usage')
        record.fetch('fingerprint')['rate_card_hash'] = @usage.rate_card_hash
        record.fetch('fingerprint')['execution_framework'] = framework(capture)
        if capture.fetch('harness_error')
          record['outcome'] = { 'state' => 'HARNESS_ERROR', 'harness_error' => 'Harbor trial failed' }
          record['score'] = 'UNKNOWN'
        end
        record
      end

      def framework(capture)
        { 'name' => 'Harbor', 'version' => HarborRuntime::VERSION,
          'environment_digest' => capture.fetch('environment').fetch('digest') }
      end

      def planned?(task)
        task.is_a?(Hash) && task['tier'] == 2 && @tasks.key?(task['id']) && RunRecord.task_errors(task).empty?
      end

      def capture(task, id)
        # Keep Harbor's 63-character verifier name truncation after the ownership prefix.
        name = "shaka-#{id.delete('-')}"
        directory = File.join(@directory, name)
        Dir.mkdir(directory, 0o700)
        success, resources = Dir.mktmpdir('controller-', @directory) do |controller|
          @runtime.launch(task: @tasks.fetch(task.fetch('id')), name: name, controller: controller,
                          directory: directory, log: File.join(directory, 'controller.log'))
        end
        trial = File.join(directory, name)
        captured(trial, name, success, resources)
      end

      def captured(trial, name, success, resources)
        native = read_result(File.join(trial, 'result.json'), name)
        images = resources.fetch('container').map do |entry|
          { 'image_digest' => entry.fetch('Image'),
            'project' => entry.dig('Config', 'Labels', 'com.docker.compose.project') }
        end
        { 'result' => native, 'images' => images,
          'environment' => HarborEnvironment.capture(resources.fetch('container'), name: name),
          'usage' => usage(trial),
          'harness_error' => !success || !native || !native['exception_info'].nil? }
      end

      def read_result(path, name)
        result = JSON.parse(File.read(path))
        result if result.is_a?(Hash) && result['trial_name'] == name
      rescue Errno::ENOENT, JSON::ParserError
        nil
      end

      def usage(trial)
        directory = File.join(File.realpath(trial), 'agent', 'sessions')
        files = Dir.glob(File.join(directory, '**/*.jsonl'))
        safe = !files.empty? && files.all? { |file| File.realpath(file).start_with?("#{directory}/") }
        return @usage.read(host: @runtime.host, files: files) if safe

        { 'models' => [], 'cache_neutral_dollars' => 'UNKNOWN', 'billed_dollars' => 'UNKNOWN' }
      end
    end
  end
end
