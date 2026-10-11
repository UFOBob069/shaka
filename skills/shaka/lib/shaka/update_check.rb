# frozen_string_literal: true

require 'json'
require 'shellwords'
require 'tmpdir'
require_relative 'doctor/installation_identity'
require_relative 'update_check/launch'
require_relative 'workflow_version'

module Shaka
  # Advisory comparison with the official main branch; never changes an installation.
  class UpdateCheck
    ROOT = File.expand_path('../../../..', __dir__)
    GUIDE = 'https://github.com/shakacode/shaka/blob/main/skills/shaka/references/official-installation.md'

    def self.run(arguments)
      return usage(arguments) unless arguments.empty?

      puts JSON.generate(installed.result)
      0
    rescue Shaka::Error, JSON::ParserError, KeyError, SystemCallError => e
      warn "Shaka update check unavailable: #{e.class}. See #{GUIDE} and retry."
      0
    end

    def self.usage(arguments)
      puts 'Usage: shaka update-check (read-only, advisory; 15-second network deadline)'
      arguments == ['--help'] ? 0 : 1
    end

    def self.installed
      identity = Doctor::InstallationIdentity.read
      record_path = File.join(ROOT, '.git/shaka-install.json')
      record = JSON.parse(File.read(record_path)) if File.file?(record_path)
      raise Shaka::Error, 'Invalid installation record' if record && !record.is_a?(Hash)

      new(source: identity.fetch('source'), branch: record&.fetch('branch', nil) || 'main',
          registered: !record.nil?, helper: File.join(ROOT, 'skills/shaka/scripts/shaka'))
    end

    private_class_method :installed, :usage

    def initialize(source:, branch:, registered:, helper:, runner: Launch.method(:capture))
      @source = source
      @branch = branch
      @registered = registered
      @helper = helper
      @runner = runner
    end

    def result
      return answer('uninstalled', 'Use the official installer to receive update guidance.') if
        @source['kind'] == 'uninstalled'
      return custom unless official?

      compare
    rescue Shaka::Error, JSON::ParserError, SystemCallError, TypeError
      unknown
    end

    private

    def official?
      origin = @source['repository'].to_s
      @source['kind'] == 'revision' && origin.match?(WorkflowVersion::UPSTREAM) && @branch == 'main' &&
        @source['revision'].to_s.match?(/\A[0-9a-f]{40}\z/)
    end

    def compare
      endpoint = "repos/shakacode/shaka/compare/#{@source.fetch('revision')}...main"
      output, _error, ok = @runner.call(['gh', 'api', '--hostname', 'github.com', endpoint, '--jq',
                                         '{status: .status}'], Dir.tmpdir)
      return unknown unless ok

      response = JSON.parse(output)
      return unknown unless response.is_a?(Hash)

      comparison(response['status'])
    end

    def comparison(status)
      case status
      when 'identical' then answer('current', 'This installed revision matches official main.')
      when 'ahead' then answer('available', update_guidance)
      when 'behind', 'diverged' then custom
      else unknown
      end
    end

    def update_guidance
      unless @registered
        return "Newer official commits are available. This is a retained copy; follow #{GUIDE} to migrate. " \
               'Keep trial and rollback copies for active chats.'
      end

      'Newer official commits are available. Finish active Shaka chats, ' \
        "run #{Shellwords.escape(@helper)} install --update, then start a new chat. " \
        'Continue this task with its saved helper.'
    end

    def custom
      answer('custom', "Fork, trial, or development source: review upstream changes through #{GUIDE}. " \
                       'Keep your chosen source and local changes; do not replace it automatically.')
    end

    def unknown
      answer('unknown', 'Could not verify update availability. Continue the task and retry `update-check` later; ' \
                        "manual update guidance: #{GUIDE}.")
    end

    def answer(status, guidance) = { 'status' => status, 'guidance' => guidance }
  end
end
