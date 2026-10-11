# frozen_string_literal: true

require 'pathname'
require_relative '../doctor/bounded_command'
require_relative '../local_review/path_guard'

module Shaka
  class UpdateCheck
    # Uses the checkout boundary even when startup happens in one of its subdirectories.
    module Launch
      def self.capture(argv, directory)
        root = candidate_root
        return ['', '', false] unless root

        path = LocalReviewPathGuard.safe_path(ENV.fetch('PATH', ''), candidate_root: root, drop_candidate: true)
        executable = LocalReviewPathGuard.safe_executable(path, 'gh', root)
        return ['', '', false] unless executable

        environment = { 'PATH' => path, 'BASH_ENV' => nil, 'ENV' => nil }
        Doctor::BoundedCommand.new(timeout: 15).call([environment, executable, *argv.drop(1)], directory)
      end

      def self.candidate_root
        directory = Pathname.new(File.realpath(Dir.pwd))
        outer = directory.ascend.to_a.reverse.find { |parent| parent.join('.git').exist? }
        outer&.to_s
      end

      private_class_method :candidate_root
    end
  end
end
