# frozen_string_literal: true

require_relative 'private_setup_test'
require_relative 'handoff_helper'
require_relative 'support/private_trial_github'
require 'shaka/pr_watch/command'

class PrivateTrialCommandTest < Minitest::Test
  include PrivateSetupFixture

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_generated_trial_publishes_walkthrough_and_hands_off_with_native_gates
    with_setup do |root, ref|
      setup_private(root, ref)
      Dir.mktmpdir do |directory|
        prepare_github(directory, ref)
        assert_native_commands(directory, root, ref)
        assert_native_watch(directory, root, ref)
        assert_merge_reads_no_private_policy(directory, root, ref)
      end
    end
  end

  def test_generated_trial_preserves_its_configured_ci_review_choice
    with_setup do |root, ref|
      selected = options.merge(review_policy: 'meaningful_changes', ci_review_jobs: ['private-review'])
      Shaka::Seam::PrivateSetup.new(root:, ref:, options: selected).setup
      watcher = Shaka::PrWatch::Command.watcher(['owner/repo', '1'], root:, ref:, head: ref)
      assert_equal ['private-review'], watcher.instance_variable_get(:@ci_jobs)
      config = Shaka::Configuration.private_source(root:, ref:).candidate_config
      assert_empty Shaka::PrWatch::Command.review_jobs({ ci_review_not_required: true }, config)
      assert_native_review_settings(config.review)
    end
  end

  private

  def assert_native_review_settings(review)
    settings = Shaka::PrWatch::Command.watch_settings({ ci_review_wait: 'all' }, nil, review:)
    assert_equal 'all', settings[:ci_review_wait]
    assert_nil settings[:seam_required_checks]
  end

  def prepare_github(directory, ref)
    script = File.join(directory, 'gh')
    File.write(script, "#!#{RbConfig.ruby}\n#{PrivateTrialGitHub::SCRIPT}")
    File.chmod(0o755, script)
    body = HandoffFixtures.description(HandoffFixtures::WIP.merge('revision' => "feature @ #{ref}"))
    File.write(File.join(directory, 'fixture.json'), JSON.generate('body' => body, 'head' => ref))
    File.write(File.join(directory, 'walkthrough.md'), walkthrough(ref))
  end

  def walkthrough(ref)
    Shaka::Publication.walkthrough(
      'identity' => HandoffFixtures::IDENTITY, 'head' => ref,
      'summary' => "[Feature](https://github.com/owner/repo/blob/#{ref}/README.md) passed validate."
    )
  end

  def assert_native_commands(directory, root, ref)
    %w[pr walkthrough handoff].each do |command|
      output, error, status = invoke(command, directory, root, ref)
      assert_predicate status, :success?, error
      result = JSON.parse(output)
      assert_equal 'github', result['requiredChecksSource'] if command == 'pr'
      assert_empty result.fetch('owed') if command == 'handoff'
    end
  end

  # Merge loads no policy from private settings, then applies its own checks.
  def assert_merge_reads_no_private_policy(directory, root, ref)
    _output, error, status = invoke('merge', directory, root, ref)
    refute_predicate status, :success?
    refute_includes error, 'Cannot read'
    assert_includes error, 'merge requires --squash-message'
  end

  def assert_native_watch(directory, root, ref)
    arguments = [COMMAND, 'pr', 'watch', 'owner/repo', '1', '--root', root, '--ref', ref,
                 '--head', ref, '--settle', '1', '--interval', '1']
    output, error, status = Open3.capture3({ 'PATH' => "#{directory}:#{ENV.fetch('PATH')}" }, *arguments)
    assert_predicate status, :success?, "#{error}\n#{output}"
    assert_equal "SHAKA_WAKE checks_terminal\n", output
  end

  def invoke(command, directory, root, ref)
    arguments = [COMMAND, command, 'owner/repo', '1', '--root', root, '--ref', ref, '--head', ref]
    arguments.push('--body-file', File.join(directory, 'walkthrough.md')) if command == 'walkthrough'
    Open3.capture3({ 'PATH' => "#{directory}:#{ENV.fetch('PATH')}" }, *arguments)
  end
end
