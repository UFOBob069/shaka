# frozen_string_literal: true

require_relative 'links'

module Shaka
  module Install
    # Migrates verified copies without removing their contents.
    class OfficialLinks < Links
      def check(target)
        ensure_safe_directory(@skills_dir, 'Host skills directory')
        validate_location(target)
        if codex? && File.directory?(codex_aliases)
          verify_safe_directory(codex_aliases,
                                'Codex legacy skills directory')
        end
        preflight(target)
      end

      def verify(target)
        @names.each do |name|
          expected = File.join(target, 'skills', name)
          raise ArgumentError, link_refusal(name, expected, target) unless linked?(name, expected)
        end
      end

      def existing_names
        current = Package::ALLOWED.select { |name| File.symlink?(destination(name)) && owned?(name) }
        return current unless codex?

        current | Package::ALLOWED.select { |name| owned_alias?(name) }
      end

      def retire_aliases
        return unless codex? && File.directory?(codex_aliases)

        with_lock(codex_aliases) do
          @names.each { |name| File.unlink(File.join(codex_aliases, name)) if owned_alias?(name) }
        end
      end

      private

      def linked?(name, expected)
        File.symlink?(destination(name)) && File.realpath(destination(name)) == expected
      rescue SystemCallError
        false
      end

      def link_refusal(name, expected, root)
        path = destination(name)
        repair = Refusal.command('ln', '-sfn', expected, path)
        return existing_refusal("Installation link differs: #{path}", name, repair) if
          File.symlink?(path) || File.exist?(path)

        Refusal.message("Installation link is missing: #{path}", "it should point to #{expected}",
                        Refusal.command(File.join(root, 'bin/install')))
      end

      def validate_location(target)
        directory = File.realpath(@skills_dir)
        root = File.realpath(target)
        raise ArgumentError, 'Skills directory overlaps installation' if
          directory == root || directory.start_with?("#{root}/") || root.start_with?("#{directory}/")
      end

      def codex? = @skills_dir == File.join(Dir.home, '.agents/skills')
      def codex_aliases = File.join(Dir.home, '.codex/skills')

      def owned_alias?(name)
        path = File.join(codex_aliases, name)
        return false unless File.symlink?(path)

        target = File.expand_path(File.readlink(path), codex_aliases)
        package = managed_package(name, target)
        source_target?(name, target) || default_package?(package)
      rescue Errno::ENOENT
        false
      end

      def default_package?(package)
        package && File.realpath(File.dirname(package)) == File.realpath(@managed) && verified_package?(package)
      end

      def managed_target?(name, target)
        package = managed_package(name, File.expand_path(target, @skills_dir))
        package && verified_package?(package)
      end

      def managed_package(name, target)
        package = File.dirname(target, 2)
        package if target == File.join(package, 'skills', name) && File.basename(package).match?(Package::ID_PATTERN)
      end

      def verified_package?(package)
        Package.new(File.dirname(package), nil, [], Tree.new(Package::ALLOWED)).verify(package)
        true
      rescue ArgumentError, SystemCallError
        false
      end
    end
  end
end
