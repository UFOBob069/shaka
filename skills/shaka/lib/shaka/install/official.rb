# frozen_string_literal: true

require 'rbconfig'
require 'shellwords'
require_relative 'checkout'
require_relative 'official_links'
require_relative 'direct_source'
require_relative 'link_lock'

module Shaka
  module Install
    # Keeps the official skill in one dedicated checkout, separate from PR trial packages.
    class Official
      include LinkLock

      HOSTS = { 'codex' => '.agents/skills', 'claude' => '.claude/skills', 'cursor' => '.cursor/skills',
                'opencode' => '.config/opencode/skills' }.freeze
      RUBY_RECORD = 'shaka-ruby'

      def initialize(source, options)
        selected = options[:directory] || registered_source(source) || File.join(Dir.home, '.agents/shaka')
        @checkout = Checkout.new(selected, **options.slice(:repository, :branch))
        @agents = options.fetch(:agents)
        @skills_dir = options[:skills_dir]
        @names = options.fetch(:names).uniq
      end

      def run(action)
        @checkout.prepare(action)
        return verify(targets_for(action)) if action == :verify

        with_lock(File.join(@checkout.root, '.git')) { install(action) }
        update_reminder
      end

      private

      def install(action)
        @checkout.prepare(action)
        targets = targets_for(action)
        links = targets.map { |target| links_for(target) }
        links.each { |entry| entry.check(@checkout.root) }
        update(targets) if action == :update && !@checkout.pending?
        @checkout.save(targets, identity(targets))
        record_ruby
        switch_links(links)
        verify(targets)
      end

      def update_reminder
        puts "Keep Shaka updated: #{Shellwords.escape(File.join(@checkout.root, 'skills/shaka/scripts/shaka'))} " \
             'install --update (finish active Shaka chats first; start a new chat afterward).'
      end

      def update(targets)
        verify(targets)
        @checkout.update { |root| identity(targets, root) }
      end

      def switch_links(links)
        links.each do |entry|
          entry.switch_all(@checkout.root)
          entry.retire_aliases
        end
      end

      def registered_source(source) = (source if File.file?(File.join(source, '.git', Checkout::RECORD)))

      def targets_for(_action)
        recorded = @checkout.record&.fetch('targets') || []
        return recorded if retain_targets?(recorded)

        (recorded + requested_targets).to_h { |target| [target.fetch('directory'), target] }.values
      end

      def retain_targets?(recorded) = !recorded.empty? && @agents.empty? && !@skills_dir && @names == ['shaka']

      def requested_targets
        selected_directories.map do |directory|
          target = { 'directory' => File.expand_path(directory), 'names' => @names }
          target['names'] = (@names + links_for(target).existing_names).uniq
          target
        end
      end

      def selected_directories
        return [@skills_dir] if @skills_dir && @agents.empty?

        raise ArgumentError, 'Choose --skills-dir or --agent, not both' if @skills_dir

        return default_directories if @agents.empty?

        @agents.uniq.map { |agent| File.join(Dir.home, host_directory(agent)) }
      end

      def host_directory(agent) = HOSTS.fetch(agent) { raise ArgumentError, "Unknown coding agent: #{agent}" }

      def default_directories
        return @checkout.record.fetch('targets').map { |target| target.fetch('directory') } if @checkout.record

        [File.join(Dir.home, HOSTS.fetch('codex'))]
      end

      def links_for(target)
        directory = target.fetch('directory')

        OfficialLinks.new(directory, File.join(Dir.home, '.local/share/shaka/installs'),
                          @checkout.root, target.fetch('names'))
      end

      def identity(targets, root = @checkout.root)
        names = targets.flat_map { |target| target.fetch('names') }.uniq
        tree = Tree.new(names)
        DirectSource.new(root, names, tree).identity(tree.hash(root))
      end

      def record_ruby
        path = File.join(@checkout.root, '.git', RUBY_RECORD)
        temporary = "#{path}.#{Process.pid}"
        File.write(temporary, "#{File.realpath(RbConfig.ruby)}\n", mode: 'wx', perm: 0o600)
        File.rename(temporary, path)
      ensure
        File.unlink(temporary) if temporary && File.exist?(temporary)
      end

      def verify_identity(targets)
        raise ArgumentError, 'Recorded installation identity differs' unless
          identity(targets) == @checkout.record['identity']
      end

      def verify(targets)
        targets.each { |target| links_for(target).verify(@checkout.root) }
        verify_identity(targets)
        ruby = File.read(File.join(@checkout.root, '.git', RUBY_RECORD)).strip
        unless File.executable?(ruby)
          raise ArgumentError,
                'Installation Ruby is unavailable; rerun bin/install with Ruby 3.4'
        end

        puts "Verified Shaka installation: #{@checkout.root} (#{@checkout.revision[0, 7]})"
      end
    end
  end
end
