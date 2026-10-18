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

      def recorded(checkout)
        checkout.record['targets'].flat_map do |target|
          target['names'].filter_map { |name| link(checkout, File.join(target['directory'], name)) }
        end
      end

      def link(checkout, path)
        return finding('B9', path, 'link is missing', command: checkout.installer) unless present?(path)
        return finding('B9', path, 'is not a link', decision: 'Move this path aside, then rerun bin/install.') unless
          File.symlink?(path)

        owner = @inventory.owner(@inventory.link_at(path))
        return if owner == checkout.root

        elsewhere(checkout, path, owner)
      end

      def elsewhere(checkout, path, owner)
        return orphan(checkout, path, owner) if @inventory.checkouts.key?(owner)
        return finding('B9', path, "points to managed copy #{owner}", command: checkout.installer) if
          @inventory.managed?(owner)

        finding('B9', path, "points to #{File.readlink(path)}, which this checkout does not own",
                decision: "Remove or keep #{path} yourself, then run #{checkout.installer}.")
      end

      def orphan(checkout, path, owner)
        record = Shellwords.escape(File.join(checkout.root, '.git', Checkout::RECORD))
        retired = "#{record}.retired-#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}"
        finding('C1', checkout.root, "#{path} belongs to the registered checkout #{owner}, so this record owns nothing",
                command: "mv #{record} #{retired}")
      end

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
