# frozen_string_literal: true

require 'optparse'
require_relative '../publication/comment_history'
require_relative '../publication/evidence_history'
require_relative '../merge_review_evidence'
require_relative 'bot_history'

module Shaka
  # Earlier reports retain their findings and their closing merge attestation.
  # A different reviewed commit is history, not proof that any concern was resolved.
  class LocalReviewHistory < CommentHistory
    MARKER = 'Earlier review — findings are not automatically resolved. Latest local review:'
    KEYS = '(?:local-adversarial-review|local-review-[0-9a-f]{40}|' \
           'local-review-loop-[0-9a-f]{12}-[0-9a-f]{12}(?:-\\d+)?)'
    KEY = /\A<!-- shaka:reply:#{KEYS} -->\n/
    PER_COMMIT = /\A<!-- shaka:reply:local-review-[0-9a-f]{40} -->\n/
    SUMMARY = 'Earlier local review'
    ATTESTATION = MergeReviewEvidence::ATTESTATION

    # Automatic publication only retires reports whose findings the current ledger accounts for.
    def initialize(github, ids: nil)
      super(github)
      @ids = ids
    end

    def self.run(arguments, github: nil)
      options = parse_options(arguments)
      return 0 unless options

      github ||= GitHub.new(*arguments)
      publish_result(collapse_selected(github, options))
    end

    def self.collapse_selected(github, options)
      if options[:superseded].any?
        EvidenceHistory.new(github).collapse(options[:superseded], current: options[:current])
      elsif options[:ids].any?
        BotReviewHistory.new(github).collapse(options[:ids], head: options[:head])
      else
        new(github).collapse
      end
    end

    def self.parse_options(arguments)
      options = { ids: [], superseded: [] }
      parser = option_parser(options)
      parser.parse!(arguments)
      return nil.tap { puts parser } if options[:help]

      check_options(arguments, options, parser)
      options
    end

    ID = /\A[1-9]\d*\z/

    def self.option_parser(options)
      OptionParser.new do |flags|
        flags.banner = 'Usage: shaka review collapse OWNER/REPO NUMBER'
        flags.on('-h', '--help') { options[:help] = true }
        flags.on('--bot-comment ID', ID, 'Obsolete bot issue comment; repeat to select several') do |id|
          options[:ids] << id.to_i
        end
        flags.on('--head SHA', /\A[0-9a-f]{40}\z/) { |sha| options[:head] = sha }
        evidence_flags(flags, options)
      end
    end

    def self.evidence_flags(flags, options)
      flags.on('--superseded ID', ID, 'Own AI-authored comment a newer one replaced; repeat to select several') do |id|
        options[:superseded] << id.to_i
      end
      flags.on('--current ID', ID, 'Own comment that replaces them') { |id| options[:current] = id.to_i }
    end

    def self.check_options(arguments, options, parser)
      raise OptionParser::InvalidArgument, parser.to_s unless arguments.length == 2
      raise OptionParser::MissingArgument, '--head for --bot-comment' if options[:ids].any? && !options[:head]
      raise OptionParser::InvalidArgument, '--head requires --bot-comment' if options[:head] && options[:ids].empty?

      check_evidence_options(options)
    end

    def self.check_evidence_options(options)
      superseded = options[:superseded].any?
      raise OptionParser::InvalidArgument, '--superseded and --current go together' unless
        superseded == !options[:current].nil?
      raise OptionParser::InvalidArgument, '--superseded cannot join --bot-comment' if superseded && options[:ids].any?
    end

    def self.publish_result(result)
      puts JSON.pretty_generate(result)
      result['unavailable'].empty? ? 0 : 1
    end

    private

    def latest_comment(comments)
      head = @github.api("repos/#{@github.repository}/pulls/#{@github.number}").dig('head', 'sha')
      comments.select { |comment| attestation(comment['body'])[1] == head && active?(comment) }
              .max_by { |comment| [per_commit?(comment) ? 0 : 1, *order(comment)] }
    end

    # A restored head needs its previously archived report republished before it can be current.
    def active?(comment)
      content = comment['body'].split("\n", 2).last.to_s
      content = content.sub(/\A🤖 [^\n]+\n\n/, '')
      !content.start_with?("#{MARKER} ")
    end

    def owned?(comment)
      super && (@ids.nil? || @ids.include?(comment['id'])) && !attestation(comment['body'].to_s).nil?
    end

    def earlier?(comment, latest)
      !active?(comment) || attestation(comment['body'])[1] != attestation(latest['body'])[1]
    end

    def per_commit?(comment) = comment['body'].to_s.match?(PER_COMMIT)

    # Returning to a reviewed head can make its comment older than the existing pointer.
    def keep_pointer?(previous, latest) = previous == latest

    def attestation(body)
      found = body.match(ATTESTATION)
      ReviewerSelection.parse(found[2]) if found
      found
    rescue Error
      nil
    end

    def footer(content) = "\n#{attestation(content)[0].strip}\n"
  end
end
