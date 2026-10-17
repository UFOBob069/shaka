# frozen_string_literal: true

require 'fileutils'
require_relative '../error'

module Shaka
  class Seam
    # Starts a worktree's private settings from another worktree's recovery copy.
    module PrivateSeed
      private

      def seeding? = @options.key?(:from)

      def seeded_files
        extra = @options.keys - %i[root ref from]
        raise Error, "--from copies existing settings; omit #{extra.join(', ')}" if extra.any?

        copy = PrivateRecovery.new(root: @root, assign_identity: false).seed_files(@options[:from])
        copy.to_h { |relative, content| [File.join(private_root, relative), content] }
      end

      # Seeded copies may hold files setup never generates, such as a custom review prompt.
      def preflight_files(files)
        return super unless seeding?

        files.each { |path, content| seeded_file_present?(path, content, seeded_mode(path)) }
      end

      def write_files(files)
        return super unless seeding?

        preflight_directories
        FileUtils.mkdir_p(private_root)
        files.each { |path, content| write_seeded_file(path, content) }
      end

      def write_seeded_file(path, content)
        mode = seeded_mode(path)
        return if seeded_file_present?(path, content, mode)

        assert_inside_private_root!(existing_parent(File.dirname(path)))
        FileUtils.mkdir_p(File.dirname(path))
        assert_inside_private_root!(File.dirname(path))
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          file.write(content)
          file.chmod(mode)
        end
      end

      # Matches the recovery copy's mode rule so an interrupted seed resumes like setup.
      def seeded_mode(path) = path.start_with?(File.join(private_root, 'bin/')) ? 0o755 : 0o644

      def private_root = File.join(@root, PrivateRecovery::PRIVATE_DIRECTORY)

      def assert_inside_private_root!(directory)
        return if "#{File.realpath(directory)}/".start_with?("#{File.realpath(private_root)}/")

        raise Error, "Refusing unsafe directory: #{directory.delete_prefix("#{@root}/")}"
      end

      def seeded_file_present?(path, content, mode)
        return false unless File.exist?(path) || File.symlink?(path)
        return true if File.file?(path) && !File.symlink?(path) && (File.stat(path).mode & 0o7777) == mode &&
                       File.binread(path) == content

        raise Error, "Refusing existing destination: #{path.delete_prefix("#{@root}/")}"
      end
    end
  end
end
