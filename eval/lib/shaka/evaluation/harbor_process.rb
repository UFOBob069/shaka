# frozen_string_literal: true

require 'json'
require 'open3'
require 'timeout'

module Shaka
  module Evaluation
    # The controller owns a process group and only this reservation's Compose resources.
    class HarborProcess
      def initialize(docker:, environment:)
        @docker = docker
        @environment = environment
      end

      def run(command, log:, seconds:)
        File.open(log, 'wx', 0o600) do |output|
          pid = Process.spawn(@environment, *command, **spawn_options, out: output, err: output)
          Timeout.timeout(seconds) { Process.wait2(pid).last.success? }
        ensure
          terminate(pid) if pid
        end
      end

      def capture(command)
        Open3.popen3(@environment, *command, **spawn_options) do |input, stdout, stderr, wait|
          input.close
          errors = Thread.new { stderr.read }
          begin
            read(stdout, wait)
          ensure
            terminate(wait.pid)
            errors.join
          end
        end
      end

      def resources(name)
        %w[container network volume].to_h do |kind|
          [kind, discover(kind, name)]
        end
      end

      def cleanup(name)
        errors = %w[container network volume].filter_map do |kind|
          remove(kind, discover(kind, name))
          nil
        rescue StandardError => e
          e
        end
        raise IOError, 'Owned resource cleanup incomplete' unless errors.empty?
      end

      private

      def spawn_options = { pgroup: true, chdir: @environment.fetch('HOME'), unsetenv_others: true }

      def discover(kind, name)
        ids = capture([@docker, kind, 'ls', *(kind == 'container' ? ['-a'] : []), '-q',
                       '--filter', 'label=com.docker.compose.project']).split
        entries = ids.empty? ? [] : JSON.parse(capture([@docker, kind, 'inspect', *ids]))
        entries.select { |entry| owned?(entry, kind, name) }
      end

      def remove(kind, entries)
        return if entries.empty?

        capture([@docker, kind, 'rm', *(kind == 'container' ? ['--force', '--volumes'] : []),
                 *entries.map { |entry| entry.fetch(kind == 'volume' ? 'Name' : 'Id') }])
      end

      def read(stdout, wait)
        Timeout.timeout(30) do
          output = stdout.read
          raise IOError, 'Controller command failed' unless wait.value.success?

          output
        end
      end

      def owned?(entry, kind, name)
        labels = kind == 'container' ? entry.dig('Config', 'Labels') : entry['Labels']
        project = labels&.fetch('com.docker.compose.project', nil)
        project.is_a?(String) && /\A#{Regexp.escape(name)}__(?:env|verifier__[a-z0-9_-]+)\z/.match?(project)
      end

      def terminate(pid)
        # A completed parent may still have descendants. Kill only its original group.
        Process.kill('TERM', -pid)
        sleep 0.1
        reap(pid, Process::WNOHANG)
        Process.kill('KILL', -pid)
      rescue Errno::ESRCH
        nil
      ensure
        reap(pid)
      end

      def reap(pid, flags = 0)
        Process.wait(pid, flags)
      rescue Errno::ECHILD
        nil
      end
    end
  end
end
