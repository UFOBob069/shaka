# frozen_string_literal: true

require 'fileutils'

module Shaka
  module Install
    # Protects an installation path from replacement through a writable ancestor.
    module DirectorySafety
      private

      def ensure_safe_directory(path, label)
        unless File.exist?(path) || File.symlink?(path)
          FileUtils.mkdir_p(path, mode: 0o755)
          File.chmod(0o755, path)
        end
        verify_safe_directory(path, label)
      end

      def verify_safe_directory(path, label)
        resolved = resolved_safe_directory(path, label)
        child = nil
        loop do
          entry = checked_directory(resolved, child, label)
          parent = File.dirname(resolved)
          break if parent == resolved

          child = entry
          resolved = parent
        end
      end

      def resolved_safe_directory(path, label)
        raise ArgumentError, "#{label} is unsafe: #{path} is a symbolic link" if File.symlink?(path)

        File.realpath(path)
      rescue Errno::ENOENT, Errno::ELOOP
        raise ArgumentError, "#{label} is unsafe: #{path} cannot be resolved"
      end

      def checked_directory(path, child, label)
        entry = File.lstat(path)
        reason = unsafe_reason(entry, child)
        raise ArgumentError, "#{label} #{child ? 'has an unsafe parent' : 'is unsafe'}: #{path} #{reason}" if reason

        entry
      rescue Errno::ENOENT, Errno::ELOOP
        raise ArgumentError, "#{label} is unsafe: #{path} cannot be resolved"
      end

      def unsafe_reason(entry, child)
        return 'is not a directory' unless entry.directory?
        return owner_reason(entry.uid, hidden: hidden_owner?(entry.uid)) unless trusted_owner?(entry)
        return unless entry.mode.anybits?(0o022)
        return 'is group or world writable' unless child

        'is group or world writable without a sticky bit protecting your directory' if unsafe_parent?(entry, child)
      end

      def owner_reason(uid, hidden:)
        reason = "is owned by uid #{uid}, not by you (uid #{Process.euid}) or root"
        return reason unless hidden

        "#{reason}. A sandbox or container is hiding the real owner; run the installer outside it"
      end

      # An owner outside this user namespace appears as the kernel's overflow UID.
      def hidden_owner?(uid, overflow: proc_text('/proc/sys/kernel/overflowuid'),
                        uid_map: proc_text('/proc/self/uid_map'))
        uid.to_s == overflow&.strip && !uid_map.nil? && !mapped_uid?(uid, uid_map)
      end

      def mapped_uid?(uid, uid_map)
        uid_map.each_line.any? do |line|
          inside, _outside, count = line.split.map(&:to_i)
          count && uid >= inside && uid < inside + count
        end
      end

      def proc_text(path)
        File.read(path)
      rescue SystemCallError
        nil
      end

      def unsafe_parent?(entry, child)
        entry.mode.anybits?(0o022) && !(entry.mode.anybits?(0o1000) && trusted_owner?(child))
      end

      def trusted_owner?(entry)
        [Process.euid, 0].include?(entry.uid)
      end
    end
  end
end
