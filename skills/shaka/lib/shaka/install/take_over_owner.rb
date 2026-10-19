# frozen_string_literal: true

module Shaka
  module Install
    # Finds the registered checkout that a take-over moves the host links away from.
    module TakeOverOwner
      private

      # The checkout whose `shaka` links the host skills directories point at, other than this one. A registered
      # checkout running the installer is a candidate too, so its own hint works for a custom skills directory.
      def owning_checkout(selected, skills_dir, invoking)
        directories = skills_dir ? [skills_dir] : host_directories
        owners = candidates(directories, invoking) - [Checkout.new(selected).root]
        return Checkout.new(owners.first).tap(&:verify_directories) if owners.size == 1
        raise ArgumentError, no_owner_message(directories) if owners.empty?

        raise ArgumentError, "Several registered checkouts own Shaka links (#{owners.join(', ')}); " \
                             'a person must choose which to keep'
      end

      def host_directories = Official::HOSTS.values.map { |path| File.join(Dir.home, path) }

      def no_owner_message(directories)
        "No other registered checkout owns the Shaka links in #{directories.join(', ')}; run --take-over " \
          "with the owner's bin/install, or add --skills-dir DIR for links in a custom skills directory"
      end

      def candidates(directories, invoking)
        (link_owners(directories) + [invoking && Checkout.new(invoking).root]).compact.uniq
      end

      def link_owners(directories)
        directories.filter_map { |directory| link_owner(File.join(directory, 'shaka')) }.uniq
      end

      def link_owner(link)
        return unless File.symlink?(link)

        owner = File.dirname(File.realpath(link), 2)
        owner if File.file?(File.join(owner, '.git', Checkout::RECORD))
      rescue Errno::ENOENT, Errno::ELOOP
        nil
      end
    end
  end
end
