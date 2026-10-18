# frozen_string_literal: true

require 'shellwords'
require_relative 'status_states'

module Shaka
  module Install
    # Compares every install record's host links with what the links really point to.
    class StatusLinks
      def initialize(inventory)
        @inventory = inventory
      end

      def findings
        @inventory.checkouts.values.flat_map { |checkout| recorded(checkout) } + unreadable + [divergent_hosts]
      end

      private

      # A record is an orphan only when none of its links still reach it; one moved link is a B9.
      def recorded(checkout)
        links = named_links(checkout)
        moved = links.reject { |path, name| exact?(checkout, path, name) }
        taken = moved.find { |path, _name| other_checkout?(checkout, owner_of(path)) }
        return [orphan(checkout, *taken)] if taken && moved.size == links.size

        moved.map { |path, name| link(checkout, path, name) }
      end

      def named_links(checkout)
        checkout.record['targets'].flat_map do |target|
          target['names'].map { |name| [File.join(target['directory'], name), name] }
        end
      end

      def link(checkout, path, name)
        return finding('B9', path, 'link is missing', command: checkout.installer) unless present?(path)
        return finding('B9', path, 'is not a link', decision: 'Move this path aside, then rerun bin/install.') unless
          File.symlink?(path)

        elsewhere(checkout, path, name, owner_of(path))
      end

      def elsewhere(checkout, path, name, owner)
        expected = File.join(checkout.root, 'skills', name)
        if owner == checkout.root
          return finding('B9', path, "points to #{File.readlink(path)}, not #{expected}",
                         command: "ln -sfn #{Shellwords.escape(expected)} #{Shellwords.escape(path)}")
        end
        return finding('B9', path, "points to managed copy #{owner}", command: checkout.installer) if
          @inventory.managed?(owner)

        finding('B9', path, "points to #{File.readlink(path)}, which this checkout does not own",
                decision: "Choose which install #{path} should use, then run that install's bin/install.")
      end

      def orphan(checkout, path, _name)
        record = Shellwords.escape(File.join(checkout.root, '.git', Checkout::RECORD))
        finding('C1', checkout.root, "#{path} belongs to the registered checkout #{owner_of(path)}, and no link " \
                                     'this record names reaches it',
                command: "mv #{record} #{record}.retired-$(date -u +%Y%m%dT%H%M%SZ)")
      end

      def exact?(checkout, path, name)
        File.symlink?(path) && @inventory.real(path) == File.join(checkout.root, 'skills', name)
      end

      def other_checkout?(checkout, owner) = owner != checkout.root && @inventory.checkouts.key?(owner)
      def owner_of(path) = @inventory.owner(@inventory.link_at(path))

      def unreadable
        @inventory.unreadable.map do |root, message|
          finding('C1', root, message,
                  decision: "Inspect #{File.join(root, '.git', Checkout::RECORD)}; rename it aside when no install " \
                            'should use this checkout.')
        end
      end

      def divergent_hosts
        owners = host_shaka_links.to_h { |entry| [entry['path'], @inventory.owner(entry) || entry['target']] }
        return if owners.values.uniq.size < 2

        finding('C5', @inventory.home, owners.map { |path, owner| "#{path} -> #{owner}" }.join('; '),
                decision: 'Choose one install, then rerun its bin/install with every --agent you use.')
      end

      def host_shaka_links
        @inventory.links.select { |entry| entry['kind'] == 'host link' && entry['name'] == 'shaka' }
      end

      def present?(path) = File.exist?(path) || File.symlink?(path)
      def finding(id, location, detail, **) = StatusStates.finding(id, location, detail, **)
    end
  end
end
