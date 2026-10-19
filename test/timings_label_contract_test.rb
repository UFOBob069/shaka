# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/decision_labels'
require 'shaka/github/pull_timeline'

# The timings predict the labels description publication sets afterwards, so the prediction must match it.
class TimingsLabelContractTest < Minitest::Test
  # Keeps a pull request's labels in memory and applies Attention's label calls to them.
  class FakeGitHub
    attr_reader :labels, :repository, :number

    def initialize(labels)
      @labels = labels.dup
      @repository = 'owner/repo'
      @number = 7
    end

    def snapshot = { 'state' => 'OPEN' }

    def api_list(path) = path.end_with?('page=1') ? @labels.map { |name| { 'name' => name } } : []

    def api(path, method: 'GET', fields: nil, **)
      name = path.split('/labels/', 2)[1]
      return { 'name' => name } if path.start_with?('repos/owner/repo/labels/')

      method == 'DELETE' ? @labels.delete(name) : @labels.concat(fields.fetch(:labels))
      @labels.map { |label| { 'name' => label } }
    end
  end

  def predicted(before, content)
    timeline = { 'labels' => before.map { |name| { 'name' => name, 'added' => true, 'at' => Time.at(0) } } }
    Shaka::PullTimeline.with_decisions(timeline, content)['labels'].each_with_object([]) do |event, active|
      event['added'] ? active.push(event['name']).uniq! : active.delete(event['name'])
    end
  end

  def test_the_prediction_matches_the_labels_publication_sets
    [[[], ['Which base?']], [['awaiting-resume'], ['Which base?']], [['awaiting-answer'], ['Which base?']],
     [['awaiting-answer'], []], [['awaiting-resume'], []], [[], []]].each do |before, decisions|
      github = FakeGitHub.new(before)
      Shaka::DecisionLabels.sync(github, { 'decisions' => decisions })
      assert_equal github.labels.sort, predicted(before, { 'decisions' => decisions }).sort, [before, decisions].inspect
    end
  end
end
