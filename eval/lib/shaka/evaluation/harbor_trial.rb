# frozen_string_literal: true

require 'tmpdir'
require_relative 'harbor_runtime'
require_relative 'harbor_environment'
require_relative 'harbor_fingerprint'
require_relative 'runner'

module Shaka
  module Evaluation
    # Reserves before launching; a trusted block supplies grading and the full record.
    class HarborTrial
      def initialize(runtime:, usage:, tasks:, directory:, fingerprints: {})
        @runtime = runtime
        @usage = usage
        @tasks = tasks.transform_values { |path| File.realpath(path) }.freeze
        @fingerprints = fingerprints
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
        valid = builder && tasks.is_a?(Array) && !tasks.empty? && tasks.all? { |task| planned?(task) }
        return if valid && valid_fingerprints?

        raise ArgumentError, 'Expected supported tasks, operator fingerprints and a trusted record builder'
      end

      def valid_fingerprints?
        @fingerprints.is_a?(Hash) && @fingerprints.all? do |id, evidence|
          @tasks.key?(id) && HarborFingerprint.valid_evidence?(evidence)
        end
      end

      def account(record, capture)
        record['usage'] = capture.fetch('usage')
        record['fingerprint'] = capture.fetch('fingerprint').merge('rate_card_hash' => @usage.rate_card_hash)
        grade(record, capture)
        if capture.fetch('harness_error')
          record['outcome'] = { 'state' => 'HARNESS_ERROR', 'harness_error' => 'Harbor trial failed' }
          record['score'] = 'UNKNOWN'
        end
        record
      end

      def grade(record, _capture) = record

      def planned?(task)
        task.is_a?(Hash) && task['tier'] == 2 && @tasks.key?(task['id']) && RunRecord.task_errors(task).empty?
      end

      def capture(task, id)
        # Keep Harbor's 63-character verifier name truncation after the ownership prefix.
        name = "shaka-#{id.delete('-')}"
        directory = File.join(@directory, name)
        Dir.mkdir(directory, 0o700)
        success, resources, package = launch(task, name, directory)
        trial = File.join(directory, name)
        result = captured(trial, name, success, resources).merge('package' => package, 'sessions' => sessions(trial),
                                                                 'directory' => trial)
        result['fingerprint'] = HarborFingerprint.read(task: task, host: @runtime.host, capture: result,
                                                       evidence: @fingerprints.fetch(task.fetch('id'), {}))
        result
      end

      def launch(task, name, directory)
        package = @runtime.skill_snapshot
        success, resources = Dir.mktmpdir('controller-', @directory) do |controller|
          @runtime.launch(task: @tasks.fetch(task.fetch('id')), name: name, controller: controller,
                          directory: directory, log: File.join(directory, 'controller.log'))
        end
        package = {} unless package == @runtime.skill_snapshot
        [success, resources, package]
      end

      def captured(trial, name, success, resources)
        native = read_result(File.join(trial, 'result.json'), name)
        images = resources.fetch('container').map do |entry|
          { 'image_digest' => entry.fetch('Image'),
            'project' => entry.dig('Config', 'Labels', 'com.docker.compose.project') }
        end
        { 'result' => native, 'images' => images, 'lock' => read_json(File.join(trial, 'lock.json')),
          'environment' => HarborEnvironment.capture(resources.fetch('container'), name: name),
          'usage' => usage(trial),
          'harness_error' => !success || !native || !native['exception_info'].nil? }
      end

      def read_result(path, name)
        result = read_json(path)
        result if result.is_a?(Hash) && result['trial_name'] == name
      end

      def read_json(path)
        result = JSON.parse(File.read(path))
        result if result.is_a?(Hash)
      rescue Errno::ENOENT, JSON::ParserError
        nil
      end

      def usage(trial)
        files = sessions(trial)
        return @usage.read(host: @runtime.host, files: files) unless files.empty?

        { 'models' => [], 'cache_neutral_dollars' => 'UNKNOWN', 'billed_dollars' => 'UNKNOWN' }
      end

      def sessions(trial)
        directory = File.join(File.realpath(trial), 'agent', 'sessions')
        files = Dir.glob(File.join(directory, '**/*.jsonl'))
        safe = !files.empty? && files.all? { |file| File.realpath(file).start_with?("#{directory}/") }
        safe ? files : []
      end
    end
  end
end
