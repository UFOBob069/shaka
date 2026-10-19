# frozen_string_literal: true

require 'shellwords'
require 'time'
require_relative 'install/locations'
require_relative 'update_check/cache'

module Shaka
  # Prints at most one stderr line when a helper call starts: a host link names a different
  # installation, or the cached update check says this installation needs attention. It reads
  # local files only, never the network, and a failure never changes the command's result.
  class StartupNotice
    VARIABLE = 'SHAKA_NOTICES'
    ROOT = File.expand_path('../../../..', __dir__)
    # update-check prints its own answer, and install reports the installation it changes.
    SKIPPED = %w[install update-check].freeze
    ACTIONABLE = %w[available drift].freeze

    def self.call(arguments, env: ENV, output: $stderr)
      return if env[VARIABLE] == 'off' || arguments.empty? || SKIPPED.include?(arguments.first)

      line = new(home: Dir.home).line
      output.puts("shaka: #{line}") if line
    rescue StandardError => e
      output.puts("shaka: notice skipped: #{e.message}")
    end

    # Claude Code adds a SessionStart hook's plain-text output to the new chat, but not a JSON answer.
    # Only the saved answer is read, so a new chat never waits on the network.
    def self.session_start(output: $stdout, home: nil, root: ROOT, now: Time.now)
      line = new(home: home || Dir.home, root:, now:).saved_update
      output.puts("Shaka update check: #{line}") if line
      0
    rescue StandardError
      0
    end

    def initialize(home:, root: ROOT, now: Time.now)
      @home = home
      @root = root
      @now = now
    end

    def line = other_installation || update

    # What the saved answer asks of a registered checkout, without the once-a-day limit.
    def saved_update = (update_line(UpdateCheck::Cache.read(@root, home: @home)) if registered?)

    private

    # A PR trial package runs on purpose beside the linked installation, so it gets no notice.
    def other_installation
      return if File.file?(File.join(@root, '.shaka-install.json'))

      own = File.realpath(File.join(@root, 'skills/shaka'))
      linked = host_links
      return if linked.empty? || linked.any? { |_link, skill| skill == own }

      link, skill = linked.first
      "This helper runs from #{@root}, but #{link} links to #{File.dirname(skill, 2)}. " \
        "Use #{Shellwords.escape(File.join(skill, 'scripts/shaka'))}."
    end

    def host_links
      Install::Locations::HOSTS.values.filter_map do |directory|
        link = File.join(@home, directory, 'shaka')
        [link, File.realpath(link)] if File.symlink?(link) && File.exist?(link)
      end
    end

    # Only a registered checkout has update answers; one notice at most per day.
    def update
      return unless registered?

      entry = UpdateCheck::Cache.read(@root, home: @home)
      return if UpdateCheck::Cache.fresh?(entry['noticed_at'], @now)

      line = update_line(entry)
      line if line && UpdateCheck::Cache.noticed(entry, @root, home: @home, now: @now)
    end

    def registered? = File.file?(File.join(@root, '.git', Install::Locations::RECORD))

    def update_line(entry)
      result = entry['result']
      unless result.is_a?(Hash) && UpdateCheck::Cache.fresh?(entry['checked_at'], @now)
        helper = Shellwords.escape(File.join(@root, 'skills/shaka/scripts/shaka'))
        return "Shaka has not checked for updates in the last day. Run #{helper} update-check."
      end

      result['guidance'] if ACTIONABLE.include?(result['status'])
    end
  end
end
