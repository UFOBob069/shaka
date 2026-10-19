# frozen_string_literal: true

require_relative 'check'

module Shaka
  class Doctor
    # Reports the `install --status` state, so a broken install shows up beside the other checks.
    class InstallationState
      include Check

      def initialize(system:)
        @system = system
      end

      def call
        report = @system.installation_status.call
        summary = "#{report.fetch('state')} #{report.fetch('title')} at #{report.fetch('location')}"
        return check('Install state', 'healthy', summary) if report.fetch('severity') == 'ok'

        step = report['next_command'] ? "Run #{report['next_command']}" : "Decide: #{report['decision']}"
        check('Install state', 'degraded', "#{summary}: #{report['detail']}",
              guidance: "#{step}. `shaka install --status` lists everything it found.")
      rescue ArgumentError, KeyError, NoMethodError, TypeError, SystemCallError => e
        check('Install state', 'degraded', "install --status could not run: #{first_line(e.message)}")
      end
    end
  end
end
