# frozen_string_literal: true

require_relative 'private_delivery_helper'

# Exercises the walkthrough command's advisory opening check against a fake GitHub and model.
class CliWalkthroughOpeningTest < Minitest::Test
  include PrivateDeliveryFixture

  # PR #666's walkthrough opened with a repository choosing and seeing.
  THING_ACTS = 'A repository can now name the providers it trusts for review, and see on the PR ' \
               'when one could not.'
  PERSON_ACTS = 'Reviewers now get inline notes on the walkthrough of any change to three or more files.'

  def test_an_opening_that_gives_a_thing_a_persons_action_is_flagged_after_publishing
    with_walkthrough_opening do
      published = publish_walkthrough(THING_ACTS)
      assert_equal 7, published['id']
      assert_equal 'flagged', published.dig('opening', 'status')
      assert_includes published.dig('opening', 'reason'), 'an action it cannot perform'
      assert_includes File.read(File.join(@state, 'opening-prompt.txt')), THING_ACTS
    end
  end

  def test_an_opening_led_by_the_people_it_affects_passes
    with_walkthrough_opening do
      assert_equal 'passed', publish_walkthrough(PERSON_ACTS).dig('opening', 'status')
    end
  end

  def test_an_unavailable_model_still_publishes_the_walkthrough
    with_walkthrough_opening do
      File.write(File.join(@state, 'claude'), "#!/bin/sh\nexit 1\n")
      published = publish_walkthrough(PERSON_ACTS)
      assert_equal 7, published['id']
      assert_equal 'not_checked', published.dig('opening', 'status')
    end
  end

  def test_without_a_reviewer_the_host_checks_the_walkthrough_opening
    with_trial do
      published = publish_walkthrough(PERSON_ACTS, reviewer: nil)
      assert_equal 'host_check', published.dig('opening', 'status')
      assert_includes published.dig('opening', 'prompt'), PERSON_ACTS
    end
  end

  private

  def with_walkthrough_opening
    with_trial do
      update_private { |data| data['opening_check'] = { 'external_enabled' => true } }
      write_executable(@state, 'claude', walkthrough_claude)
      yield
    end
  end

  def publish_walkthrough(summary, reviewer: 'anthropic/claude')
    path = File.join(@state, 'walkthrough.json')
    link = "[Feature](https://github.com/owner/repo/blob/#{@ref}/feature) carries the change."
    File.write(path, JSON.generate('identity' => { 'agent' => 'Codex' }, 'summary' => summary,
                                   'sections' => [{ 'heading' => 'Change', 'body' => link }]))
    flags = reviewer ? ['--opening-reviewer', reviewer] : []
    invoke('walkthrough', '--head', @ref, '--content-file', path, *flags)
  end

  # Answers only once the fake GitHub holds the review, so a pass proves the check ran after publishing.
  def walkthrough_claude
    <<~RUBY
      require 'json'
      prompt = STDIN.read
      File.write(File.join(Dir.home, 'opening-prompt.txt'), prompt)
      abort 'walkthrough was not published' unless JSON.parse(File.read(File.join(Dir.home, 'pull.json')))['review']
      thing = prompt.include?(#{THING_ACTS.inspect})
      sentence = { 'character' => thing ? 'A repository' : 'Reviewers', 'reader_facing' => true,
                   'character_can_act' => !thing, 'action' => thing ? 'can name and see' : 'get',
                   'object' => 'inline notes', 'hidden_actions' => [], 'internal_terms' => [] }
      puts JSON.generate('is_error' => false, 'result' => JSON.generate('sentences' => [sentence]))
    RUBY
  end
end
