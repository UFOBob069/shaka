# frozen_string_literal: true

require_relative '../error'
require_relative '../walkthrough/notes'

module Shaka
  # Posts a walkthrough review with its inline notes and confirms GitHub kept every note.
  module WalkthroughNotePosting
    RESOLUTION_QUERY = <<~GRAPHQL
      query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $number) {
            baseRefName
            baseRef { refUpdateRule { requiresConversationResolution } }
          }
        }
      }
    GRAPHQL

    private

    # GitHub refuses the whole review when one note's lines are outside the diff, so nothing is posted.
    def create_walkthrough(head, body, notes)
      fields = { event: 'COMMENT', commit_id: head, body: body }
      return api(reviews_path, method: 'POST', fields:) if notes.empty?

      refuse_blocking_notes
      post_with_notes(fields, notes)
    end

    def post_with_notes(fields, notes)
      api(reviews_path, method: 'POST', fields: fields.merge(comments: notes))
    rescue Error => e
      raise Error, "#{e.message} GitHub refuses the whole review when a note sits on lines the diff " \
                   "does not show; check #{notes.map { |note| Walkthrough::Notes.location(note) }.join(', ')}."
    end

    # The current notes stay open until a newer walkthrough, so they would block such a merge.
    def refuse_blocking_notes
      owner, name = @repository.split('/')
      pull = graphql(RESOLUTION_QUERY, { owner:, name:, number: @number }).dig('repository', 'pullRequest')
      branch = pull['baseRefName'] if pull.is_a?(Hash)
      raise Error, 'GitHub did not report the pull request base branch.' unless branch.is_a?(String)
      return unless pull.dig('baseRef', 'refUpdateRule', 'requiresConversationResolution') ||
                    branch_rules(branch).any? { |rule| resolution_rule?(rule) }

      raise Error, "#{branch} requires conversation resolution before merging; publish the walkthrough without notes."
    end

    def resolution_rule?(rule)
      rule.is_a?(Hash) && rule['type'] == 'pull_request' &&
        rule.dig('parameters', 'required_review_thread_resolution') == true
    end

    def verify_notes(id, notes)
      return if notes.empty?

      stored = api_list("#{reviews_path}/#{id}/comments?per_page=100").map { |note| note.values_at('path', 'body') }
      return if stored.sort == notes.map { |note| note.values_at('path', 'body') }.sort

      raise Error, "Published walkthrough review #{id} did not keep its #{notes.size} notes."
    end
  end
end
