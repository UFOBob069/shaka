# frozen_string_literal: true

require 'fileutils'
require_relative 'harbor_process'
require_relative 'skill_snapshot'

module Shaka
  module Evaluation
    # Operator-owned controller and prepared tasks; never take these paths from an agent.
    class HarborRuntime
      REVISION = 'b53b8134e1241686dca7759af188f987ecc48e8b'
      VERSION = '0.24.0'

      def initialize(tools:, credential:, skill:, profile:, path: ENV.fetch('PATH'))
        @harbor, @source, @docker, @credential, @skill = [*tools.values_at('harbor', 'source', 'docker'),
                                                          credential, skill].map do |value|
          raise ArgumentError, 'Expected absolute controller paths' unless value.is_a?(String) && value.start_with?('/')

          File.realpath(value)
        end
        @profile = profile.dup.freeze
        @path = path
        validate_profile
        @secret = subscription
      end

      def preflight(directory)
        env = environment(directory)
        raise ArgumentError, 'Expected selected Docker on controller PATH' unless selected_docker?(env.fetch('HOME'))

        process = HarborProcess.new(docker: @docker, environment: env)
        clean = process.capture(['git', '-C', @source, 'status', '--porcelain']).strip.empty?
        revision = process.capture(['git', '-C', @source, 'rev-parse', 'HEAD']).strip
        version = process.capture([@harbor, '--version']).strip
        return if clean && revision == REVISION && version == VERSION

        raise ArgumentError, "Expected clean pinned Harbor #{VERSION}"
      end

      def config(task:, name:, directory:)
        { 'task' => { 'path' => task }, 'trial_name' => name, 'trials_dir' => directory,
          'agent' => { 'name' => @profile.fetch('host'), 'model_name' => @profile.fetch('model'),
                       'skills' => [@skill], 'kwargs' => @profile.slice('version', 'reasoning_effort') },
          'environment' => { 'import_path' => 'capability_upload:CapabilityUploadDocker', 'delete' => false,
                             'kwargs' => { 'keep_containers' => true } } }
      end

      def launch(task:, name:, controller:, directory:, log:)
        configuration = File.join(controller, 'config.json')
        write_config(configuration, task: task, name: name, directory: directory)
        env = environment(controller)
        credential(env, controller)
        process = HarborProcess.new(docker: @docker, environment: env)
        success = execute(process, configuration, log)
        [success, process.resources(name)]
      ensure
        # Discovery is repeated after interruption or a failed native process.
        process&.cleanup(name)
      end

      def host = @profile.fetch('host')
      def skill_snapshot = SkillSnapshot.read(@skill)

      private

      def selected_docker?(home)
        paths = @path.split(File::PATH_SEPARATOR, -1).map { |entry| File.expand_path(File.join(entry, 'docker'), home) }
        selected = paths.find { |path| File.file?(path) && File.executable?(path) }
        selected && File.realpath(selected) == @docker
      end

      def execute(process, configuration, log)
        process.run([@harbor, 'trial', 'start', '--config', configuration], log: log,
                                                                            seconds: @profile.fetch('timeout_seconds'))
      rescue Timeout::Error
        false
      end

      def write_config(path, **inputs)
        File.write(path, JSON.generate(config(**inputs)), mode: 'wx', perm: 0o600)
      end

      def validate_profile
        valid = %w[codex claude-code].include?(host) && /\A\d+\.\d+\.\d+\z/.match?(@profile.fetch('version')) &&
                %w[low medium high xhigh max].include?(@profile.fetch('reasoning_effort')) &&
                valid_execution?
        raise ArgumentError, 'Expected explicit host, model, CLI version, effort and bounded timeout' unless valid
      end

      def valid_execution?
        @profile.fetch('model').is_a?(String) && !@profile.fetch('model').strip.empty? &&
          @profile.fetch('timeout_seconds').is_a?(Integer) && @profile.fetch('timeout_seconds').between?(1, 3600)
      end

      def environment(directory)
        directory = File.realpath(directory)
        %w[home tmp].each { |part| FileUtils.mkdir_p(File.join(directory, part), mode: 0o700) }
        { 'PATH' => @path, 'HOME' => File.join(directory, 'home'), 'TMPDIR' => File.join(directory, 'tmp'),
          'PYTHONPATH' => [File.join(@source, 'src'), File.expand_path('../../../harbor_spike', __dir__)].join(':'),
          'HARBOR_TELEMETRY' => 'off', 'LITELLM_LOCAL_MODEL_COST_MAP' => 'True', 'SPIKE_SKILL_DIR' => @skill,
          'PYTHON_DOTENV_DISABLED' => '1',
          'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC' => '1' }
      end

      def credential(env, directory)
        if host == 'codex'
          path = File.join(directory, 'codex-auth.json')
          File.write(path, @secret, mode: 'wx', perm: 0o600)
          env['CODEX_AUTH_JSON_PATH'] = path
        else
          env['CLAUDE_FORCE_OAUTH'] = '1'
          env['CLAUDE_CODE_OAUTH_TOKEN'] = @secret
        end
      end

      def subscription
        secret = File.read(@credential).strip
        valid = host == 'codex' ? codex_subscription?(secret) : !secret.empty?
        raise ArgumentError, 'Expected selected subscription credentials' unless valid

        secret
      end

      def codex_subscription?(secret)
        data = JSON.parse(secret)
        data.is_a?(Hash) && data['OPENAI_API_KEY'].to_s.empty? &&
          data.dig('tokens', 'access_token').is_a?(String) && !data.dig('tokens', 'access_token').empty?
      rescue JSON::ParserError, TypeError
        false
      end
    end
  end
end
