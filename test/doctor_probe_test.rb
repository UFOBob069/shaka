# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'
require_relative 'repository_fixture'
require 'shaka/doctor/reviewer_probe'

# Uses fake reviewer executables; no account requests leave the machine.
module DoctorProbeFixture
  AGENT = { 'provider' => 'openai', 'model_family' => 'codex', 'model' => 'gpt-6-sol', 'effort' => 'medium' }.freeze
  # The stub reviewer exits at once, so this limit only matters when a busy machine delays its start.
  LAUNCH_TIMEOUT = 10

  private

  def with_candidate_git(root)
    original = ENV.fetch('PATH')
    directory = File.join(root, 'bin')
    FileUtils.mkdir_p(directory)
    marker = File.join(root, 'untrusted-git-ran')
    write_candidate_git(directory, marker)
    ENV['PATH'] = "#{directory}:#{original}"
    yield marker
    assert_equal "#{directory}:#{original}", ENV.fetch('PATH')
  ensure
    ENV['PATH'] = original
  end

  def write_candidate_git(directory, marker)
    File.write(File.join(directory, 'git'), "#!/bin/sh\ntouch '#{marker}'\nexit 1\n")
    File.chmod(0o700, File.join(directory, 'git'))
  end

  def nested_candidate_probe(root, path, trace)
    ref = commit_probe_configuration(root)
    nested = File.join(root, 'subdir')
    unsafe = File.join(root, 'bin')
    FileUtils.mkdir_p([nested, unsafe])
    marker = File.join(root, 'untrusted-codex-ran')
    write_codex(unsafe, marker, success: true)
    write_codex(path, trace, success: true)
    subject = Shaka::Doctor::ReviewerProbe.new(root: nested, path: "#{unsafe}:#{path}", timeout: LAUNCH_TIMEOUT, ref:)
    [subject, marker]
  end

  def change_candidate_model(root)
    config = seam('review' => review_policy('local_review_agents' => [AGENT.merge('model' => 'gpt-6-astra')]))
    File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(config))
  end

  def with_probe
    with_repository('review' => review_policy('local_review_agents' => [AGENT])) do |root|
      Dir.mktmpdir('doctor-probe-cli') do |path|
        yield root, path, File.join(path, 'trace.json')
      end
    end
  end

  def commit_probe_configuration(root)
    commands = [%w[init -q], %w[config user.email fixture@example.com], %w[config user.name Fixture],
                %w[add .], %w[commit -qm fixture]]
    commands.each { |arguments| system(TEST_GIT, '-C', root, *arguments, exception: true) }
    Open3.capture2(TEST_GIT, '-C', root, 'rev-parse', 'HEAD').first.strip
  end

  def with_timeout_capture(deadlines)
    original = Shaka::LocalReviewProcess.method(:capture)
    Shaka::LocalReviewProcess.define_singleton_method(:capture, timeout_capture(deadlines))
    yield
  ensure
    Shaka::LocalReviewProcess.define_singleton_method(:capture, original) if original
  end

  def timeout_capture(deadlines)
    lambda do |_args, **options|
      deadlines << options.fetch(:timeout)
      ['', '', nil]
    end
  end

  def probe(root, path, agent: AGENT, timeout: LAUNCH_TIMEOUT)
    review = { 'local_review_agents' => [agent] }
    Shaka::Doctor::ReviewerProbe.new(root:, path:, timeout:).call(review)
  end

  def write_codex(path, trace, success:)
    File.write(File.join(path, 'codex'), codex_script(trace, success))
    File.chmod(0o700, File.join(path, 'codex'))
  end

  def codex_script(trace, success)
    <<~RUBY
      #!#{RbConfig.ruby}
      require 'json'
      trace = #{trace.inspect}
      count = File.exist?(trace) ? JSON.parse(File.read(trace)).fetch('count') + 1 : 1
      File.write(trace, JSON.generate(args: ARGV, cwd: Dir.pwd, count: count))
      STDIN.read
      if #{success}
        File.write(ARGV.fetch(ARGV.index('-o') + 1), 'OK')
      else
        puts JSON.generate(type: 'error', message: "The 'gpt-6-sol' model is not supported when using Codex with a ChatGPT account.")
        exit 1
      end
    RUBY
  end
end

class DoctorProbeTest < Minitest::Test
  include DoctorHelper
  include RepositoryConfigTestHelpers
  include DoctorProbeFixture

  def test_probe_preserves_settings_and_runs_once_outside_the_candidate
    with_probe do |root, path, trace|
      write_codex(path, trace, success: true)
      item = probe(root, path)
      invocation = JSON.parse(File.read(trace))

      assert_probe_invocation(item, invocation, root)
    end
  end

  def test_account_refusal_is_reported_without_retry_or_provider_outage_claim
    with_probe do |root, path, trace|
      write_codex(path, trace, success: false)
      item = probe(root, path)

      assert_equal 'failed', item.fetch(:status)
      assert_includes item.fetch(:summary), 'account_model_refused'
      assert_includes item.fetch(:summary), 'diagnostic'
      assert_includes item.fetch(:guidance), 'user'
      assert_equal 1, JSON.parse(File.read(trace)).fetch('count')
    end
  end

  def test_doctor_does_not_probe_without_explicit_opt_in
    with_probe do |root, path, trace|
      write_codex(path, trace, success: true)
      doctor(root:, environment: { 'PATH' => path })
      refute_path_exists trace
    end
  end

  def test_unsupported_adapter_is_unverified_without_a_launch
    with_probe do |root, path, trace|
      item = probe(root, path, agent: { 'provider' => 'custom', 'model_family' => 'reviewer' })
      assert_equal 'degraded', item.fetch(:status)
      assert_includes item.fetch(:summary), 'unsupported'
      refute_path_exists trace
    end
  end

  def test_malformed_claude_effort_stops_before_probe
    with_probe do |root, path, trace|
      item = probe(root, path, agent: { 'provider' => 'anthropic', 'model_family' => 'claude', 'effort' => 'turbo' })
      assert_equal 'failed', item.fetch(:status)
      assert_includes item.fetch(:summary), 'not one of'
      refute_path_exists trace
    end
  end

  def test_timeout_reports_failure_and_never_retries
    with_probe do |root, path, trace|
      write_codex(path, trace, success: true)
      deadlines = []
      item = with_timeout_capture(deadlines) { probe(root, path, timeout: 1) }
      assert_equal 'failed', item.fetch(:status)
      assert_includes item.fetch(:summary), 'timed out after 1s'
      assert_equal [1], deadlines
      refute_path_exists trace
    end
  end

  def test_probe_reaches_the_doctor_report_once
    with_probe do |root, path, trace|
      write_codex(path, trace, success: true)
      settings = { timeout: LAUNCH_TIMEOUT, ref: commit_probe_configuration(root) }
      subject = Shaka::Doctor.new(root:, environment: { 'PATH' => path },
                                  system: stub_system(DEFAULTS), probe: settings)
      assert_includes subject.report, '[HEALTHY] Reviewer availability'
      refute_includes subject.report, 'no reviewer was launched'
      subject.blocked?
      assert_equal 1, JSON.parse(File.read(trace)).fetch('count')
    end
  end

  private

  def assert_probe_invocation(item, invocation, root)
    assert_equal 'healthy', item.fetch(:status)
    assert_includes invocation.fetch('args'), 'gpt-6-sol'
    assert_includes invocation.fetch('args'), 'model_reasoning_effort="medium"'
    assert_includes invocation.fetch('args'), '--ignore-user-config'
    refute invocation.fetch('cwd').start_with?(root)
    assert_equal 1, invocation.fetch('count')
    refute_path_exists invocation.fetch('cwd')
    assert_includes item.fetch(:summary), 'not a completed review'
  end
end

# Covers configuration reads before any potentially billable launch.
class DoctorProbeTrustTest < Minitest::Test
  include DoctorHelper
  include RepositoryConfigTestHelpers
  include DoctorProbeFixture

  def test_candidate_settings_cannot_choose_billable_probe_settings
    with_probe do |root, path, trace|
      ref = commit_probe_configuration(root)
      change_candidate_model(root)
      write_codex(path, trace, success: true)
      item = Shaka::Doctor::ReviewerProbe.new(root:, path:, timeout: LAUNCH_TIMEOUT, ref:).for_repository
      assert_equal 'healthy', item.fetch(:status)
      assert_includes JSON.parse(File.read(trace)).fetch('args'), 'gpt-6-sol'
    end
  end

  def test_missing_ref_does_not_launch_a_billable_probe
    with_probe do |root, path, trace|
      write_codex(path, trace, success: true)
      item = Shaka::Doctor::ReviewerProbe.new(root:, path:, timeout: LAUNCH_TIMEOUT).for_repository
      assert_equal 'failed', item.fetch(:status)
      refute_path_exists trace
    end
  end

  def test_nested_root_cannot_launch_an_executable_elsewhere_in_the_checkout
    with_probe do |root, path, trace|
      subject, marker = nested_candidate_probe(root, path, trace)
      item = subject.for_repository
      assert_equal 'healthy', item.fetch(:status)
      refute_path_exists marker
      assert_path_exists trace
    end
  end

  def test_candidate_git_is_not_used_to_read_trusted_probe_settings
    with_probe do |root, path, trace|
      ref = commit_probe_configuration(root)
      write_codex(path, trace, success: true)
      with_candidate_git(root) do |marker|
        item = Shaka::Doctor::ReviewerProbe.new(root:, path:, timeout: LAUNCH_TIMEOUT, ref:).for_repository
        assert_equal 'healthy', item.fetch(:status)
        refute_path_exists marker
        assert_includes JSON.parse(File.read(trace)).fetch('args'), 'gpt-6-sol'
      end
    end
  end
end
