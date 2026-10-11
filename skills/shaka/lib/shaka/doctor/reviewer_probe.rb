# frozen_string_literal: true

require 'tmpdir'
require 'tempfile'
require_relative 'check'
require_relative '../reviewer_selection'
require_relative '../reviewer_settings'
require_relative '../local_review/cli'
require_relative '../opening_publication'

module Shaka
  class Doctor
    # An explicit, potentially billable availability check using the reviewer's isolated adapter.
    class ReviewerProbe
      include Check

      PROMPT = 'Reply OK only. Do not use tools, read files, or perform a review.'
      GUIDANCE = 'Inspect local diagnostics. Keep configured model and effort; ask the user before changing them. ' \
                 'Timeouts and account model refusals do not establish a provider outage.'

      def initialize(root:, path:, timeout:, ref: nil)
        @root = OpeningCheckout.root(root) || File.realpath(root)
        @path = LocalReviewPathGuard.safe_path(path, candidate_root: @root, drop_candidate: true)
        @timeout = timeout
        @ref = ref
      end

      def for_repository
        raise Shaka::Error, '--ref must be a verified default-branch SHA' unless
          @ref.to_s.match?(/\A[0-9a-f]{40}(?:[0-9a-f]{24})?\z/)

        OpeningPublication.with_safe_path(root: @root, select_gh: false) do
          call(Configuration.trusted(root: @root, ref: @ref, candidate_commands: false).review)
        end
      rescue Shaka::Error, SystemCallError => e
        check('Reviewer availability', 'failed', "not probed: #{first_line(e.message)}")
      end

      def call(review)
        return check('Reviewer availability', 'degraded', 'not probed: repository seam is not healthy') unless review

        entries = Array(review['local_review_agents'])
        return check('Reviewer availability', 'degraded', 'No configured CLI reviewers to probe.') if entries.empty?

        results = entries.map { |entry| probe(entry) }
        status = results.map(&:first).max_by { |value| SEVERITY.fetch(value) }
        check('Reviewer availability', status, results.map(&:last).join("\n    "), guidance: GUIDANCE)
      end

      private

      def probe(entry)
        identity = entry.values_at('provider', 'model_family').join('/').downcase
        label = entry_label(identity, entry)
        return ['degraded', "#{label}: unverified; unsupported CLI adapter."] unless
          ReviewerSelection::SUPPORTED_REVIEWERS.include?(identity)

        validate_settings!(identity, entry)
        result = launch(identity, entry)
        result ? failed_probe(label, result) : ['healthy', "#{label}: responded; not a completed review."]
      rescue Shaka::Error, SystemCallError => e
        ['failed', "#{label}: not completed: #{first_line(e.message)}"]
      end

      def entry_label(identity, entry)
        "#{identity} model #{entry.fetch('model', 'CLI default')} effort #{entry.fetch('effort', 'CLI default')}"
      end

      def validate_settings!(identity, entry)
        OpenrouterReview.validate!(entry.transform_keys(&:to_sym)) if identity == 'deepseek/openrouter'
        ReviewerSettings.refuse!(ReviewerSettings.notices(identity, model: entry['model'], effort: entry['effort']))
        raise Shaka::Error, 'model is required for Grok; not launched' if identity == 'xai/grok' && !entry['model']
      end

      def failed_probe(label, result)
        detail = [result['failure_cause'], result.fetch('reason'), result['guidance']].compact.join('; ')
        detail += "; local diagnostic: #{result['diagnostic_path']}" if result['diagnostic_path']
        ['failed', "#{label}: #{detail}"]
      end

      def validate_tempdir!
        directory = File.realpath(Dir.tmpdir)
        raise Shaka::Error, 'Temporary reviewer directory is inside the candidate checkout' if
          directory == @root || directory.start_with?("#{@root}/")
      end

      def launch(identity, entry)
        validate_tempdir!
        options = { reviewer: identity, model: entry['model'], effort: entry['effort'],
                    timeout_seconds: @timeout, capture_usage: false }.compact
        Dir.mktmpdir('shaka-doctor-probe-') do |neutral|
          Tempfile.create(['shaka-doctor-probe-', '.txt']) do |report|
            LocalReviewCli.new(options, root: neutral, report: report.path, candidate_root: @root, path: @path)
                          .run(PROMPT)
          end
        end
      end
    end
  end
end
