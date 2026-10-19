# frozen_string_literal: true

require 'json'
require 'shellwords'

module Shaka
  module Install
    # Words every installer refusal the same way: the state, where it was found, and one next step.
    module Refusal
      PATH_LIMIT = 5
      RECORD = 'shaka-install.json'

      module_function

      def message(state, found, next_step, note: nil)
        [state, "Found: #{found}", note, "Next: #{next_step}"].compact.join('. ')
      end

      def command(*words) = Shellwords.join(words.map(&:to_s))

      def decide(question, purpose, command) = "a person must decide #{question}; #{purpose}, run #{command}"

      def paths(list)
        shown = list.first(PATH_LIMIT).join(', ')
        list.size > PATH_LIMIT ? "#{shown} and #{list.size - PATH_LIMIT} more" : shown
      end

      def branch(repository, branch) = "the registered branch (origin/#{branch} of #{url(repository)})"

      # Refusals are read by agents and pasted into PRs, so an HTTP URL's credentials never appear in one.
      # The placeholder stays visible, so a reader knows to supply them before running a printed command.
      # Matching to the last @ before the path covers passwords that themselves contain @.
      def url(value)
        value.to_s.sub(%r{\A(https?://)[^/]*@}i, '\\1CREDENTIALS@')
             .sub(%r{\A([a-z][a-z0-9+.-]*://)[^/@]*:[^/]*@}i, '\\1CREDENTIALS@')
      end

      # Names the installation whose checkout holds a skill link's target, from that checkout's own record.
      def owner(target)
        checkout = File.dirname(target, 2)
        record = JSON.parse(File.read(File.join(checkout, '.git', RECORD)))
        "the installation at #{checkout}, which follows #{branch(record.fetch('repository'), record.fetch('branch'))}"
      rescue StandardError
        nil
      end
    end
  end
end
