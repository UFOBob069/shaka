# frozen_string_literal: true

require 'json'
require_relative 'checkout_development'
require_relative 'checkout_drift'
require_relative 'checkout_git'
require_relative 'checkout_record'
require_relative 'checkout_validation'
require_relative 'directory_safety'
require_relative 'package'

module Shaka
  module Install
    # Updates a registered checkout only from its expected origin and branch.
    class Checkout
      include DirectorySafety
      include CheckoutGit
      include CheckoutDrift
      include CheckoutDevelopment
      include CheckoutRecord
      include CheckoutValidation

      REPOSITORY = 'https://github.com/shakacode/shaka.git'
      RECORD = 'shaka-install.json'
      attr_reader :root, :record

      def initialize(directory, repository: nil, branch: nil)
        @root = File.expand_path(directory)
        @root = File.realpath(@root) if File.directory?(@root)
        @repository = repository
        @branch = branch
      end

      def prepare(action)
        @action = action
        prepare_directory(action)
        @record = read_record
        raise ArgumentError, 'Register this installation first with bin/install' if action != :install && !@record

        select_source
        validate
      end

      def update(&)
        git('fetch', '--quiet', 'origin', @branch)
        validate
        candidate = git('rev-parse', "refs/remotes/origin/#{@branch}")
        refuse_rewrite(candidate)
        stage(candidate, &)
        write_record(@record.merge('pending_revision' => candidate))
        advance(candidate)
      end

      def pending? = @record['pending_revision'] == revision

      def save(targets, identity)
        data = { 'schema_version' => 1, 'directory' => @root, 'repository' => @repository,
                 'branch' => @branch, 'revision' => revision, 'targets' => targets, 'identity' => identity }
        write_record(data)
      end

      private

      def write_record(data)
        path = File.join(@root, '.git', RECORD)
        temporary = "#{path}.#{Process.pid}"
        File.write(temporary, "#{JSON.pretty_generate(data)}\n", mode: 'wx', perm: 0o600)
        File.rename(temporary, path)
        @record = data
      ensure
        File.unlink(temporary) if temporary && File.exist?(temporary)
      end

      def prepare_directory(action)
        if action == :install
          ensure_safe_directory(@root, 'Installation directory')
          @root = File.realpath(@root)
          clone if Dir.empty?(@root)
        end
        verify_directories
      end

      def select_source
        @repository ||= @record&.fetch('repository') || REPOSITORY
        @branch = @branch || @record&.fetch('branch') || 'main'
      end

      def clone
        @repository ||= REPOSITORY
        @branch ||= 'main'
        git('clone', '--quiet', '--branch', @branch, '--', @repository, @root)
      end
    end
  end
end
