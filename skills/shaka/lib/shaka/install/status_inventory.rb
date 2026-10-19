# frozen_string_literal: true

require_relative 'official'
require_relative 'status_checkout'

module Shaka
  module Install
    # Finds every Shaka link, install record, and PR trial a status report names.
    class StatusInventory
      attr_reader :home, :source, :checkouts, :links, :unreadable

      def initialize(source:, home:, directory: nil)
        @home = home
        @source = real(source) || File.expand_path(source)
        @directory = directory
        @checkouts = {}
        @unreadable = {}
        discover
      end

      def host_directories = Official::HOSTS.values.map { |directory| File.join(@home, directory) }
      def default_directory = File.join(@home, '.local/share/shaka/source')
      def old_directory = File.join(@home, '.agents/shaka')
      def trial_directory = File.join(@home, '.local/share/shaka/pr-trials')
      def trials = entries(trial_directory).select { |path| File.directory?(path) }

      # Link owners that are linked worktrees, which go away when their branch is cleaned up. A submodule
      # or a --separate-git-dir clone also has a .git file, but its gitdir is not under worktrees/.
      def worktrees
        @links.filter_map { |link| owner(link) }.uniq.select { |root| linked_worktree?(root) }
      end

      def linked_worktree?(root)
        marker = File.join(root, '.git')
        File.file?(marker) && File.read(marker)[/\Agitdir: (.+)$/, 1].to_s.match?(%r{/worktrees/[^/]+\z})
      rescue SystemCallError
        false
      end

      def links_to(root) = @links.select { |link| owner(link) == root }
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
        candidates = [@source, default_directory, old_directory, *@directory]
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

        record = Checkout.new(root).read_record
        @checkouts[root] = StatusCheckout.new(root, record) if record
      rescue ArgumentError => e
        @unreadable[root] = e.message
      end

      def scan
        (host_directories + recorded_directories).uniq.flat_map { |directory| links_in(directory) }
      end

      def recorded_directories
        @checkouts.values.flat_map { |checkout| checkout.record['targets'].map { |target| target['directory'] } }
      end

      def links_in(directory)
        Package::ALLOWED.filter_map do |name|
          path = File.join(directory, name)
          next unless File.symlink?(path)

          { 'path' => path, 'name' => name, 'target' => File.readlink(path), 'resolved' => real(path) }
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
