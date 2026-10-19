# frozen_string_literal: true

require 'json'
require_relative 'status_inventory'
require_relative 'status_links'
require_relative 'status_healthy'
require_relative 'status_unsupported'
require_relative 'status_text'

module Shaka
  module Install
    # The install command's --status and --json flags.
    module StatusFlags
      private

      def status_options(options)
        options.on('--status', 'Name the installation state and one next step; changes nothing') { @actions << :status }
        options.on('--json', 'With --status, print the report as JSON') { @options[:json] = true }
      end

      def validate_status
        raise ArgumentError, '--json works only with --status' if @options[:json] && @actions != [:status]
      end

      def print_status = Status.new(source: @source, directory: @options[:directory]).print(json: @options[:json])
    end

    # Names the installation state with one next step. Read-only and offline: it never fetches,
    # creates a directory, or rewrites a record or link.
    class Status
      def initialize(source:, directory: nil, home: Dir.home)
        @inventory = StatusInventory.new(source:, directory:, home:)
        @healthy = StatusHealthy.new(@inventory)
      end

      def call
        findings = problems
        chosen = first_problem(findings) || @healthy.finding
        title, severity = StatusStates::STATES.fetch(chosen['id'])
        { 'schema_version' => 1, 'state' => chosen['id'], 'title' => title, 'severity' => severity,
          **chosen.slice('location', 'detail', 'next_command', 'decision'),
          'variants' => @healthy.variants, 'findings' => findings.map { |item| item.except('rank') },
          'inventory' => inventory }
      end

      def render(report = call) = StatusText.render(report)

      def print(json: false)
        report = call
        puts json ? JSON.pretty_generate(report) : render(report)
      end

      private

      def first_problem(findings)
        ranked = findings.group_by { |item| item['rank'] || item['id'] }
        StatusStates::PROBLEMS.lazy.filter_map { |id| ranked[id]&.first }.first
      end

      def problems
        findings = @inventory.checkouts.values.flat_map(&:findings) + StatusLinks.new(@inventory).findings +
                   StatusUnsupported.new(@inventory).findings
        findings << @healthy.unregistered_helper
        findings.compact.uniq { |item| [item['id'], item['location']] }
      end

      def inventory
        { 'checkouts' => @inventory.checkouts.values.map { |checkout| checkout_entry(checkout) },
          'unreadable_records' => @inventory.unreadable.keys,
          'links' => @inventory.links.map { |link| link_entry(link) },
          'trials' => @inventory.trials }
      end

      def link_entry(link) = link.slice('path', 'target').merge('owner' => @inventory.owner(link))

      def checkout_entry(checkout)
        { 'root' => checkout.root, 'repository' => StatusStates.redact(checkout.record['repository']),
          **checkout.record.slice('branch', 'revision'),
          'targets' => checkout.record['targets'] }
      end
    end
  end
end
