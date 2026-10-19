# frozen_string_literal: true

require 'English'

module Shaka
  module Install
    # Moves every host link from the registered checkout that owns them to this one, as one step.
    module TakeOver
      private

      # A take-over clones the repository and branch the previous checkout follows unless told otherwise.
      def source_options(options)
        record = @owner&.read_record || {}
        { repository: options[:repository] || record['repository'], branch: options[:branch] || record['branch'] }
      end

      # Both checkout locks in path order, so two opposite take-overs cannot wait on each other.
      def take_over
        with_locks(checkout_lock_directories) do
          @checkout.prepare(:install)
          targets = take_over_targets
          links = targets.map { |target| links_for(target, previous_source: @owner.root) }
          links.each { |entry| entry.check(@checkout.root) }
          move(targets, links)
          links.each(&:retire_aliases)
          verify(targets)
        end
      end

      def checkout_lock_directories = [@checkout.root, @owner.root].map { |root| File.join(root, '.git') }.sort

      # Holding every host lock until the records change keeps a rollback from undoing another install.
      def with_host_locks(links, &) = with_locks(links.map(&:lock_directory).uniq.sort, &)

      def with_locks(directories, &)
        return yield if directories.empty?

        with_lock(directories.first) { with_locks(directories.drop(1), &) }
      end

      def move(targets, links)
        recorded = identity(targets)
        record_ruby
        with_host_locks(links) { move_links(links) { @checkout.save(targets, recorded) } }
      end

      def take_over_targets
        owner = @owner.read_record or
          raise ArgumentError, "#{@owner.root} is no longer registered; run bin/install --take-over again"
        recorded = (@checkout.record&.fetch('targets') || []) + owner.fetch('targets')
        recorded.group_by { |target| target.fetch('directory') }.map do |directory, entries|
          { 'directory' => directory, 'names' => entries.flat_map { |target| target.fetch('names') }.uniq }
        end
      end

      # Until the new record is saved, a failure or an interrupt puts every host's links and the old record back.
      # Signals wait while the records change and while rolling back, so neither step is left half done.
      def move_links(links, &)
        previous = links.map(&:snapshot)
        links.each { |entry| entry.switch_locked(@checkout.root) }
        commit(&)
        puts "Retired previous installation record: #{@retired}"
      rescue StandardError, SignalException
        raise if @committed

        deferring_signals { roll_back(links, previous) }
        raise
      end

      def commit(&)
        deferring_signals do
          retire_owner(&)
          @committed = true
        end
      end

      # Holds Ctrl-C and SIGTERM until the block finishes, then raises the first one that arrived.
      def deferring_signals
        pending = nil
        previous = %w[INT TERM].to_h { |name| [name, trap(name) { pending ||= name }] }
        yield
      ensure
        previous.each { |name, handler| trap(name, handler || 'DEFAULT') }
        raise SignalException, pending if pending && !$ERROR_INFO
      end

      def roll_back(links, previous)
        failed = !restore_owner_record
        links.zip(previous).reverse_each do |entry, links_before|
          failed = true unless entry.restore_locked(links_before).empty?
        rescue SystemCallError, IOError => e
          warn "Could not restore links in #{entry.lock_directory}: #{e.message}"
          failed = true
        end
        return warn("Take-over failed; links point at #{@owner.root} again") unless failed

        warn 'Take-over failed and could not undo every step; repair the paths named above by hand'
      end

      # Renames the previous record so its checkout stops claiming the links; the checkout itself stays.
      def retire_owner
        stamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
        retired = File.join(@owner.root, '.git', "shaka-install.retired-#{stamp}.json")
        raise ArgumentError, "Retired installation record already exists: #{retired}" if File.exist?(retired)

        @retired = retired
        File.rename(owner_record, retired)
        yield
      end

      # Returns false when the old record stays retired.
      def restore_owner_record
        return true unless @retired && File.exist?(@retired) && !File.exist?(owner_record)

        File.rename(@retired, owner_record)
        true
      rescue SystemCallError => e
        warn "Could not restore #{owner_record} from #{@retired}: #{e.message}"
        false
      end

      def owner_record = File.join(@owner.root, '.git', Checkout::RECORD)
    end
  end
end
