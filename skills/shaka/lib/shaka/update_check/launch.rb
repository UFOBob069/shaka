# frozen_string_literal: true

require 'pathname'
require_relative '../doctor/bounded_command'
require_relative '../local_review/path_guard'

module Shaka
  class UpdateCheck
    # Uses the checkout boundary even when startup happens in one of its subdirectories.
    module Launch
      # A command that could not run, with a stable reason for the JSON answer.
      class Unavailable < Shaka::Error
        attr_reader :reason

        def initialize(reason, message)
          @reason = reason
          super(message)
        end
      end

      def self.capture(argv, directory)
        name = argv.first
        path, executable = locate(name)
        raise Unavailable.new("#{name}_missing", "`#{name}` was not found on PATH.") unless executable

        Doctor::BoundedCommand.new(timeout: 15).call([environment(path), executable, *argv.drop(1)], directory)
      end

      def self.locate(name)
        root = candidate_root
        path = LocalReviewPathGuard.safe_path(absolute_path, candidate_root: root, drop_candidate: true)
        [path, LocalReviewPathGuard.safe_executable(path, name, root)]
      rescue Shaka::Error => e
        raise Unavailable.new('unsafe_path', "`#{name}` was not run: #{e.message}.")
      end

      # Pull request content arrives as a Git checkout, so outside every repository the user's own
      # PATH applies and only the installed source checkout is kept out of it.
      def self.candidate_root
        directory = Pathname.new(File.realpath(Dir.pwd))
        outer = directory.ascend.to_a.reverse.find { |parent| parent.join('.git').exist? }
        outer&.to_s || ROOT
      end

      # A relative entry, including an empty one, names a folder under wherever the check started.
      def self.absolute_path
        ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).select { |entry| entry.start_with?('/') }
           .join(File::PATH_SEPARATOR)
      end

      def self.environment(path)
        ENV.keys.grep(/\AGIT_/).to_h { |key| [key, nil] }.merge('PATH' => path, 'BASH_ENV' => nil, 'ENV' => nil)
      end

      private_class_method :locate, :candidate_root, :absolute_path, :environment
    end
  end
end
