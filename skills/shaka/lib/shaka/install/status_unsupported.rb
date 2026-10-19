# frozen_string_literal: true

require 'open3'
require 'shellwords'
require_relative 'status_states'

module Shaka
  module Install
    # Reports a source checkout that is a linked worktree with the one command that replaces it: clone
    # into the default location, remove the old links, and install there with the same selections.
    class StatusUnsupported
      TOWERS = { 'rct' => '--with-rct', 'mct' => '--with-mct', 'mct-claude' => '--with-claude-towers',
                 'rct-claude' => '--with-claude-towers' }.freeze
      DECIDE = 'Reinstall into ~/.local/share/shaka/source with the hosts, skills folders, and towers you use ' \
               '(one bin/install run per host whose towers differ); see official-installation.md.'

      def initialize(inventory)
        @inventory = inventory
      end

      def findings
        @inventory.worktrees.map do |root|
          replace('C3', root, 'the source checkout is a linked worktree, which goes away when its branch is cleaned up',
                  selected(root, @inventory.links_to(root)))
        end
      end

      private

      # The host folders and skills the worktree serves, and the origin to clone it from again.
      def selected(root, links)
        hosts = links.group_by { |link| File.dirname(link['path']) }
        { 'directories' => hosts.keys, 'names' => links.map { |link| link['name'] },
          'targets' => hosts.values.map { |group| group.map { |link| link['name'] }.sort },
          'repository' => origin(root) }
      end

      # Reading one config value runs no program the checkout's config names.
      def origin(root)
        output, process = Open3.capture2e(ENV.keys.grep(/\AGIT_/).to_h { |key| [key, nil] },
                                          'git', '-C', root, 'config', '--get', 'remote.origin.url')
        url = output.strip
        url if process.success? && !url.empty?
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
        !File.exist?(@inventory.default_directory) && selection['targets'].uniq.size == 1 &&
          !StatusStates.credentials?(selection['repository'])
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
