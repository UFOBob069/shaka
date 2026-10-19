# frozen_string_literal: true

require 'shellwords'
require_relative 'status_states'

module Shaka
  module Install
    # Names a working installation's variant and checks which registered checkout this helper is.
    class StatusHealthy
      TRIALS = 'Trials stay until you remove them; Shaka never deletes them.'

      def initialize(inventory)
        @inventory = inventory
      end

      def finding
        return state(chosen, primary.root, command: "#{primary.helper} install --update") if primary
        return state('A8', @inventory.trial_directory, decision: TRIALS) if chosen == 'A8'

        nothing
      end

      # A copy or download without bin/install cannot install itself, so it gets a decision.
      def nothing
        installer = File.join(@inventory.source, 'bin/install')
        return state('none', @inventory.source, command: Shellwords.escape(installer)) if File.file?(installer)

        state('none', @inventory.source, decision: 'Install Shaka from a clone; see official-installation.md.')
      end

      def unregistered_helper
        source = @inventory.source
        return if @inventory.checkouts.key?(source) || @inventory.links.any? { |link| @inventory.owner(link) == source }
        return unless primary

        StatusStates.finding('A9', source, "this helper runs from #{source}, but Shaka links point to #{primary.root}",
                             command: "#{primary.helper} install --status")
      end

      def variants
        @variants ||= [*primary_variants, *('A8' if @inventory.trials.any?)]
      end

      private

      def primary_variants
        return [] unless primary

        found = { 'A5' => custom_source?, 'A4' => custom_skills?, 'A3' => custom_directory?, 'A6' => towers?,
                  'A2' => targets.size > 1 }.select { |_id, present| present }.keys
        found.intersect?(%w[A2 A3 A4 A5]) ? found : found << 'A1'
      end

      def chosen = StatusStates::HEALTHY.find { |candidate| variants.include?(candidate) }
      def targets = primary.record['targets']
      def custom_source? = primary.record['repository'] != Checkout::REPOSITORY || primary.record['branch'] != 'main'
      def custom_directory? = primary.root != @inventory.real(@inventory.default_directory)
      def towers? = targets.flat_map { |target| target['names'] }.uniq != ['shaka']

      def custom_skills?
        hosts = @inventory.host_directories.flat_map { |path| [path, @inventory.real(path)].compact }
        (targets.map { |target| target['directory'] } - hosts).any?
      end

      # The registered checkout the host links use, so a status from anywhere names the same one.
      def primary
        @primary ||= begin
          owners = @inventory.links.filter_map { |link| @inventory.owner(link) }
          @inventory.checkouts.values.find { |checkout| owners.include?(checkout.root) } ||
            @inventory.checkouts.values.first
        end
      end

      def state(id, location, **) = StatusStates.finding(id, location, nil, **)
    end
  end
end
