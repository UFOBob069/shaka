# frozen_string_literal: true

require 'shellwords'
require_relative 'status_states'

module Shaka
  module Install
    # Reports source checkouts Shaka no longer supports, each with the one command that replaces it:
    # clone into the default location, remove the old links, and install there with the same selections.
    class StatusUnsupported
      TOWERS = { 'rct' => '--with-rct', 'mct' => '--with-mct', 'mct-claude' => '--with-claude-towers',
                 'rct-claude' => '--with-claude-towers' }.freeze
      DECIDE = 'Reinstall into ~/.local/share/shaka/source with the hosts, skills folders, and towers you use ' \
               '(one bin/install run per host whose towers differ); see official-installation.md.'

      def initialize(inventory)
        @inventory = inventory
      end

      def findings
        old_location + @inventory.worktrees.map do |root|
          replace('C3', root, 'the source checkout is a linked worktree, which is deleted when its branch merges',
                  selected(@inventory.links_to(root)))
        end
      end

      private

      def old_location
        old = @inventory.real(@inventory.old_directory)
        @inventory.checkouts.values.select { |checkout| checkout.root == old }.map do |checkout|
          replace('E1', checkout.root, 'the source checkout sits at the settings path', recorded(checkout.record))
        end
      end

      # The host folders and skill names the old checkout serves, from its record when it has one.
      def recorded(record)
        { 'directories' => record['targets'].map { |target| target['directory'] },
          'names' => record['targets'].flat_map { |target| target['names'] },
          'targets' => record['targets'].map { |target| target['names'].sort },
          'repository' => record['repository'], 'branch' => record['branch'] }
      end

      def selected(links)
        { 'directories' => links.map { |link| File.dirname(link['path']) },
          'names' => links.map { |link| link['name'] } }
      end

      def replace(id, root, reason, selection)
        detail = "#{reason}; reinstall into #{@inventory.default_directory}"
        hosts = hosts(selection['directories'].uniq)
        return StatusStates.finding(id, root, detail, decision: DECIDE) unless hosts && command?(selection)

        StatusStates.finding(id, root, detail, command: command(selection, @inventory.links_to(root), hosts))
      end

      def command(selection, links, hosts)
        target = @inventory.default_directory
        steps = ["git clone #{escape(*branch(selection), repository(selection), target)}"]
        steps << "rm -- #{escape(*links.map { |link| link['path'] })}" if links.any?
        steps << escape(File.join(target, 'bin/install'), '--directory', target, *source(selection), *hosts,
                        *towers(selection))
        steps.join(' && ')
      end

      # One command can repeat one selection for every host, into a destination git clone accepts.
      def command?(selection)
        !File.exist?(@inventory.default_directory) && (selection['targets'] || [[]]).uniq.size == 1
      end

      def repository(selection) = selection['repository'] || Checkout::REPOSITORY

      def branch(selection)
        name = selection['branch'] || 'main'
        name == 'main' ? [] : ['--branch', name]
      end

      def source(selection)
        named = repository(selection) == Checkout::REPOSITORY ? [] : ['--repository', repository(selection)]
        named + branch(selection)
      end

      # Hosts take --agent; one custom folder takes --skills-dir; the installer accepts no mix of the two.
      def hosts(directories)
        agents = directories.map { |directory| agent(directory) }
        return agents.flat_map { |name| ['--agent', name] } if agents.all?

        ['--skills-dir', directories.first] if directories.size == 1
      end

      def agent(directory)
        forms = [File.expand_path(directory), @inventory.real(directory)].compact
        Official::HOSTS.find do |_name, path|
          host = File.join(@inventory.home, path)
          forms.include?(host) || forms.include?(@inventory.real(host))
        end&.first
      end

      def towers(selection) = selection['names'].filter_map { |name| TOWERS[name] }.uniq
      def escape(*words) = words.map { |word| Shellwords.escape(word) }.join(' ')
    end
  end
end
