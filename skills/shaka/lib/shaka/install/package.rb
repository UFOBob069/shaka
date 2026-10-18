# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'tmpdir'
require_relative 'package_verification'
require_relative 'display'

module Shaka
  module Install
    # Copies selected skills into a managed directory; see install/README.md.
    class Package
      include PackageVerification

      METADATA = '.shaka-install.json'
      ALLOWED = %w[shaka rct mct mct-claude rct-claude].freeze
      ID_PATTERN = /\A[A-Za-z0-9._+-]+-[0-9a-f]{64}-[0-9a-f]{64}\z/

      def self.identity_for(version, source)
        "#{version}-#{source.fetch('content_sha256')}-#{Digest::SHA256.hexdigest(JSON.generate(source))}"
      end

      # Known skills in ALLOWED order, without duplicates, so flag order cannot change the package.
      # Unknown names stay at the end for valid_skills? to refuse.
      def self.ordered_skills(names) = (ALLOWED & names) | names

      def self.valid_skills?(names)
        names.is_a?(Array) && names.include?('shaka') && names.uniq == names && (names - ALLOWED).empty?
      end

      def initialize(root, source, names, tree)
        @root = root
        @source = source
        @names = names
        @tree = tree
      end

      def prepare(source_root)
        raise ArgumentError, 'Managed package skills are invalid' unless self.class.valid_skills?(@names)

        ensure_managed_root
        hash = @tree.hash(source_root, normalized: true)
        identity = @source.identity(hash)
        version = @source.version
        stage(source_root, identity, version)
      end

      def existing(id)
        verify_managed_root
        raise ArgumentError, 'Invalid package identity' unless id.match?(ID_PATTERN)

        path = File.join(@root, id)
        metadata = verified_metadata(path)
        recorded = metadata.fetch('skills')
        raise ArgumentError, 'Rollback flags must match the package skills' unless recorded.sort == @names.sort

        path
      end

      def verify(path)
        verified_metadata(path)
        path
      end

      private

      def verify_source(source_root, hash, identity, version)
        current_hash = @tree.hash(source_root, normalized: true)
        raise ArgumentError, 'Source changed during installation' unless current_hash == hash
        raise ArgumentError, 'Source identity changed during installation' unless @source.identity(hash) == identity
        raise ArgumentError, 'Source version changed during installation' unless @source.version == version
      end

      def stage(source_root, identity, version)
        staging = Dir.mktmpdir('.staging-', @root)
        begin
          build(staging, source_root, identity, version)
        ensure
          FileUtils.chmod_R(0o700, staging) if File.directory?(staging)
          FileUtils.rm_rf(staging)
        end
      end

      def build(staging, source_root, identity, version)
        hash = identity.fetch('content_sha256')
        @tree.copy(source_root, staging)
        raise ArgumentError, 'Source changed during installation' unless @tree.hash(staging) == hash

        verify_source(source_root, hash, identity, version)

        Display.write(staging, version, identity)
        package_identity = identity.merge('package_content_sha256' => @tree.hash(staging))
        target = File.join(@root, self.class.identity_for(version, package_identity))
        write_metadata(staging, target, package_identity, version)
        @tree.reject_checkout_references(staging, source_root)
        finish(staging, target, source_root, identity, version)
      end

      def finish(staging, target, source_root, identity, version)
        if File.exist?(target) || File.symlink?(target)
          verify(target)
          verify_source(source_root, identity.fetch('content_sha256'), identity, version)
        else
          publish(staging, target)
        end
        target
      end

      def write_metadata(staging, target, identity, version)
        metadata = { 'schema_version' => 1, 'package_id' => File.basename(target),
                     'version' => version, 'skills' => @names, 'source' => identity }
        File.write(File.join(staging, METADATA), "#{JSON.pretty_generate(metadata)}\n")
        File.chmod(0o644, File.join(staging, METADATA))
      end

      def publish(staging, target)
        File.chmod(0o755, staging)
        File.rename(staging, target)
      rescue Errno::EEXIST, Errno::ENOTEMPTY
        verify(target)
      end
    end
  end
end
