# frozen_string_literal: true

require_relative 'official'
require_relative 'status_checkout'

module Shaka
  module Install
    # Finds every Shaka link, install record, managed copy, and PR trial a status report names.
    class StatusInventory
      attr_reader :home, :source, :checkouts, :links, :unreadable

      def initialize(source:, home:)
        @home = home
        @source = real(source) || File.expand_path(source)
        @checkouts = {}
        @unreadable = {}
        discover
      end

      def host_directories = Official::HOSTS.values.map { |directory| File.join(@home, directory) }
      def default_directory = File.join(@home, '.agents/shaka')
      def managed_directory = File.join(@home, '.local/share/shaka/installs')
      def trial_directory = File.join(@home, '.local/share/shaka/pr-trials')
      def aliases = @links.select { |link| link['kind'] == 'codex alias' }

      def managed_copies
        entries(managed_directory).select { |path| File.basename(path).match?(Package::ID_PATTERN) }
      end

      def trials = entries(trial_directory).select { |path| File.directory?(path) }

      def managed?(owner) = owner && File.dirname(owner) == real(managed_directory)
      def managed_links = @links.select { |link| managed?(owner(link)) }
      def link_at(path) = @links.find { |link| link['path'] == path } || { 'resolved' => real(path) }

      def real(path)
        File.realpath(path)
      rescue SystemCallError
        nil
      end

      # The checkout or package a link resolves into, or nil when it resolves nowhere Shaka knows.
      def owner(link)
        resolved = link['resolved']
        return unless resolved

        root = File.dirname(resolved, 2)
        root if File.basename(File.dirname(resolved)) == 'skills'
      end

      private

      def discover
        candidates = [@source, default_directory]
        loop do
          candidates.each { |root| register(root) }
          @links = scan
          found = (@links.filter_map { |link| owner(link) } - candidates)
          break if found.empty?

          candidates += found
        end
      end

      def register(root)
        root = real(root)
        return if root.nil? || @checkouts.key?(root) || @unreadable.key?(root)
        return unless File.directory?(File.join(root, '.git'))

        record = Checkout.new(root).send(:read_record)
        @checkouts[root] = StatusCheckout.new(root, record) if record
      rescue ArgumentError => e
        @unreadable[root] = e.message
      end

      def scan
        directories = (host_directories + recorded_directories).uniq
        links = directories.flat_map { |directory| links_in(directory, 'host link') }
        links + links_in(File.join(@home, '.codex/skills'), 'codex alias')
      end

      def recorded_directories
        @checkouts.values.flat_map { |checkout| checkout.record['targets'].map { |target| target['directory'] } }
      end

      def links_in(directory, kind)
        Package::ALLOWED.filter_map do |name|
          path = File.join(directory, name)
          next unless File.symlink?(path)

          { 'path' => path, 'name' => name, 'kind' => kind, 'target' => File.readlink(path), 'resolved' => real(path) }
        end
      end

      def entries(directory)
        Dir.children(directory).sort.map { |entry| File.join(directory, entry) }
      rescue SystemCallError
        []
      end
    end
  end
end
