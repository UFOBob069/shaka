# frozen_string_literal: true

require_relative '../install/status'

module Shaka
  class Doctor
    # Everything doctor reaches outside its own process, in one place so a test can state
    # the machine it describes instead of inheriting the one it runs on.
    PACKAGE_ROOT = File.expand_path('../../../../..', __dir__)

    System = Struct.new(:runner, :usage_source, :host_name, :ruby_version, :cursor_stop_hook, :executable,
                        :installation_status, keyword_init: true) do
      def self.default
        new(runner: RUNNER, usage_source: ->(name) { Usage::READERS.fetch(name).discover },
            host_name: MachineAlias.system_name, ruby_version: RUBY_VERSION,
            cursor_stop_hook: -> { CursorStopHook.installed? },
            executable: ->(name, path, root) { LocalReviewPathGuard.safe_executable(path, name, root) },
            installation_status: -> { Install::Status.new(source: PACKAGE_ROOT).call })
      end
    end
  end
end
