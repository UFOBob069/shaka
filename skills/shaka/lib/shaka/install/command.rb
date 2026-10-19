# frozen_string_literal: true

require 'optparse'
require_relative '../installer'
require_relative 'official'

module Shaka
  module Install
    # One entry point for the official checkout and explicit managed-copy operations.
    class Command
      VALUES = { '--directory DIR' => :directory, '--repository URL' => :repository,
                 '--branch NAME' => :branch, '--skills-dir DIR' => :skills_dir,
                 '--managed-dir DIR' => :managed_dir, '--rollback PACKAGE_ID' => :rollback }.freeze

      def initialize(source, program: 'bin/install')
        @source = source
        @program = program
        @options = { agents: [], names: ['shaka'] }
        @actions = []
      end

      def run(arguments)
        parser.parse!(arguments)
        validate(arguments)
        install
        0
      rescue OptionParser::ParseError, SystemCallError, IOError, ArgumentError => e
        warn e.message
        1
      end

      private

      def parser
        OptionParser.new do |options|
          options.banner = "Usage: #{@program} [--directory DIR] [--agent NAME] [--update|--verify]"
          VALUES.each { |flag, key| options.on(flag) { |value| @options[key] = value } }
          selections(options)
          actions(options)
        end
      end

      def selections(options)
        options.on('--agent NAME', 'codex, claude, cursor, or opencode; repeat for several') do |value|
          @options[:agents] << value
        end
        options.on('--with-mct') { @options[:names] << 'mct' }
        options.on('--with-rct') { @options[:names] << 'rct' }
        options.on('--with-claude-towers') { @options[:names].push('mct-claude', 'rct-claude') }
        options.on('--managed', 'Explicit managed copy (normally use a PR trial)') { @options[:managed] = true }
      end

      def actions(options)
        options.on('--update') { @actions << :update }
        options.on('--verify') { @actions << :verify }
        options.on('--take-over', 'Move every host link from the checkout that owns them to this one') do
          @options[:take_over] = true
        end
        options.on('-h', '--help') do
          puts options
          exit
        end
      end

      def validate(arguments)
        raise OptionParser::InvalidArgument, arguments.join(' ') unless arguments.empty?
        raise ArgumentError, 'Choose only one of --update and --verify' if @actions.size > 1

        VALUES.each_value do |key|
          raise ArgumentError, "#{key} must not be empty" if @options[key]&.strip == ''
        end
        validate_agents
        validate_action
        validate_take_over
        validate_managed if managed?
      end

      def validate_agents
        if @options[:skills_dir] && @options[:agents].any?
          raise ArgumentError,
                'Choose --skills-dir or --agent, not both'
        end

        @options[:agents].each do |agent|
          raise ArgumentError, "Unknown coding agent: #{agent}" unless Official::HOSTS.key?(agent)
        end
      end

      def validate_action
        if @actions.empty? || (@options[:agents].empty? && @options.values_at(:skills_dir, :repository,
                                                                              :branch).none? &&
                  @options[:names] == ['shaka'])
          return
        end

        raise ArgumentError, 'Use bin/install to change installation selections before maintenance'
      end

      def validate_take_over
        return if !@options[:take_over] ||
                  (@actions.empty? && @options[:agents].empty? && @options[:names] == ['shaka'] && !managed?)

        raise ArgumentError, 'Use --take-over alone or with --directory, --repository, --branch, or --skills-dir'
      end

      def validate_managed
        raise ArgumentError, 'Managed installation requires --skills-dir' unless @options[:skills_dir]
        return if @actions.empty? && @options[:agents].empty? &&
                  @options.values_at(:directory, :repository, :branch).none?

        raise ArgumentError, 'Managed options cannot be combined with official checkout options'
      end

      def managed? = @options.values_at(:managed, :managed_dir, :rollback).any? || legacy_target?

      def legacy_target?
        @options[:skills_dir] && !@options[:directory] && @options[:agents].empty? && @actions.empty? &&
          !@options[:take_over]
      end

      def install
        if managed?
          Installer.new(source_root: @source, **@options.slice(:skills_dir, :names, :managed_dir, :rollback)).run
        else
          Official.new(@source, @options)
                  .run(@actions.first || :install)
        end
      end
    end
  end
end
