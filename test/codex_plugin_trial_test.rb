# frozen_string_literal: true

require_relative 'test_helper'
load File.expand_path('../eval/bin/codex-plugin-trial', __dir__)

class CodexPluginTrialTest < Minitest::Test
  class FailingUpdate < CodexPluginTrial
    attr_reader :directory

    def prepare(directory)
      @directory = directory
      @report = { 'fresh_install' => true }
    end

    def install; end

    def update
      File.read(File.join(@directory, 'missing-cache-entry'))
    end
  end

  def test_failed_update_retains_observations_and_cleans_up_the_trial
    trial = FailingUpdate.new
    result = trial.run

    assert_true result.fetch('fresh_install')
    assert_equal 'Errno::ENOENT', result.fetch('trial_error').fetch('class')
    assert_includes result.fetch('trial_error').fetch('message'), 'missing-cache-entry'
    refute_path_exists trial.directory
  end
end
