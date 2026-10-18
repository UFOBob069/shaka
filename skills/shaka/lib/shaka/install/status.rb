# frozen_string_literal: true

require_relative 'status_inventory'
require_relative 'status_links'
require_relative 'status_healthy'
require_relative 'status_text'

module Shaka
  module Install
    # Names the installation state with one next step. Read-only and offline: it never fetches,
    # creates a directory, or rewrites a record or link.
    class Status
      def initialize(source:, home: Dir.home)
        @inventory = StatusInventory.new(source:, home:)
        @healthy = StatusHealthy.new(@inventory)
      end

      def call
        findings = problems
        chosen = StatusStates::PROBLEMS.lazy.filter_map { |id| findings.find { |item| item['id'] == id } }.first
        chosen ||= @healthy.finding
        title, severity = StatusStates::STATES.fetch(chosen['id'])
        { 'schema_version' => 1, 'state' => chosen['id'], 'title' => title, 'severity' => severity,
          **chosen.slice('location', 'detail', 'next_command', 'decision'),
          'variants' => @healthy.variants, 'findings' => findings, 'inventory' => inventory }
      end

      def render(report = call) = StatusText.render(report)

      private

      def problems
        findings = @inventory.checkouts.values.flat_map(&:findings) + StatusLinks.new(@inventory).findings
        findings << @healthy.unregistered_helper
        findings.compact.uniq { |item| [item['id'], item['location']] }
      end

      def inventory
        { 'checkouts' => @inventory.checkouts.values.map { |checkout| checkout_entry(checkout) },
          'unreadable_records' => @inventory.unreadable.keys,
          'links' => @inventory.links.map { |link| link_entry(link) },
          'managed_copies' => @inventory.managed_copies, 'trials' => @inventory.trials }
      end

      def link_entry(link) = link.slice('path', 'kind', 'target').merge('owner' => @inventory.owner(link))

      def checkout_entry(checkout)
        { 'root' => checkout.root, **checkout.record.slice('repository', 'branch', 'revision'),
          'targets' => checkout.record['targets'] }
      end
    end
  end
end
