# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'
require 'yaml'

# Stub claude, codex, and grok CLIs. Reviewer selection skips a CLI missing from PATH, so tests that
# expect a listed reviewer to be chosen put these first to stay independent of the test machine.
module ReviewerCliStubs
  def self.path(rest = ENV.fetch('PATH')) = "#{directory}:#{rest}"

  # One directory per process: parallel test workers must not remove each other's stubs.
  def self.directory
    return @directory if @pid == Process.pid

    @pid = Process.pid
    @directory = Dir.mktmpdir('shaka-reviewer-clis')
    %w[claude codex grok].each do |name|
      File.write(File.join(@directory, name), "#!/bin/sh\nexit 1\n")
      File.chmod(0o700, File.join(@directory, name))
    end
    directory = @directory
    at_exit { FileUtils.rm_rf(directory) if Process.pid == @pid }
    @directory
  end
end

# A throwaway repository whose seam lists Claude, Codex, and Grok, and a runner for `shaka reviewer`.
module ReviewerCommandFixture
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  private

  def reviewer(root, *)
    env = { 'PATH' => ReviewerCliStubs.path('/usr/bin:/bin'), 'OPENROUTER_API_KEY' => nil,
            'SHAKA_RUBY' => RbConfig.ruby }
    output, error, status = Open3.capture3(env, COMMAND, 'reviewer', '--root', root, *)
    raise error unless status.success?

    JSON.parse(output)
  end

  def rewrite_reviewers(root, reviewers)
    path = File.join(root, '.agents/agent-workflow.yml')
    config = YAML.safe_load_file(path)
    config['review']['local_review_agents'] = reviewers
    File.write(path, YAML.dump(config))
  end

  def with_repository
    Dir.mktmpdir('shaka-reviewer') do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/bin'))
      %w[setup validate test].each { |name| write_command(root, name) }
      File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(config))
      yield root
    end
  end

  def write_command(root, name)
    path = File.join(root, '.agents/bin', name)
    File.write(path, "#!/bin/sh\nexit 0\n")
    File.chmod(0o755, path)
  end

  def config
    { 'version' => 1, 'base_branch' => 'main',
      'review' => { 'required' => 'meaningful_changes', 'ci_review_jobs' => ['claude-review'],
                    'local_review_agents' => [{ 'provider' => 'anthropic', 'model_family' => 'claude' },
                                              { 'provider' => 'openai', 'model_family' => 'codex' },
                                              { 'provider' => 'xai', 'model_family' => 'grok' }] },
      'merge' => { 'preference' => 'ask' } }
  end
end
