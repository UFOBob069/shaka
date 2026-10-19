# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/doctor'
require 'stringio'

class DoctorCliTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_an_unexpected_argument_is_refused_rather_than_ignored
    assert_equal(1, silently { Shaka::Doctor.run(['unexpected']) })
  end

  def test_help_does_not_inspect_the_machine
    assert_equal(0, silently { Shaka::Doctor.run(['--help']) })
  end

  # OpenCode exposes no session identifier, so detection falls back to codex; stating the
  # host must reach the report instead of silently checking the wrong one.
  def test_a_stated_host_replaces_detection
    system = Shaka::Doctor::System.new(runner: ->(*) { ['', 'stub', false] },
                                       host_name: 'test-machine', ruby_version: RUBY_VERSION,
                                       executable: ->(*) { false },
                                       usage_source: ->(host) { host == 'opencode' ? [__FILE__] : [] })
    subject = Shaka::Doctor.new(root: File.expand_path('..', __dir__), host: 'opencode',
                                environment: {}, system: system)
    assert_includes subject.report, 'opencode'
    refute_includes subject.report, 'detected'
  end

  # End to end through the real command, with a stub gh so no request leaves the machine.
  def test_the_command_reports_every_check_and_exits_non_zero_when_something_blocks
    output, error, status = stub_gh { |path, root| capture_doctor(path, root) }

    refute_predicate status, :success?, 'a missing repository seam must block'
    assert_includes output, 'Repository seam'
    assert_includes output, 'Machine alias'
    assert_empty error
  end

  def test_probe_deadline_requires_opt_in_and_has_a_small_bound
    [%w[--probe-reviewers], %w[--probe-reviewers --ref HEAD], %w[--ref HEAD],
     %w[--probe-timeout-seconds 1], %w[--probe-reviewers --probe-timeout-seconds 0],
     %w[--probe-reviewers --probe-timeout-seconds 121],
     %w[--probe-reviewers --installation-json]].each do |arguments|
      assert_equal(1, silently { Shaka::Doctor.run(arguments) })
    end
  end

  def test_each_probe_only_flag_names_itself_without_probe_reviewers
    { %w[--ref HEAD] => '--ref', %w[--probe-timeout-seconds 1] => '--probe-timeout-seconds' }.each do |arguments, flag|
      error = StringIO.new
      original = $stderr
      $stderr = error
      assert_equal 1, Shaka::Doctor.run(arguments)
      assert_includes error.string, "#{flag} requires --probe-reviewers"
    ensure
      $stderr = original
    end
  end

  private

  def capture_doctor(path, root)
    Open3.capture3({ 'PATH' => path }, COMMAND, 'doctor', '--root', root)
  end

  def stub_gh
    Dir.mktmpdir do |stub|
      File.write(File.join(stub, 'gh'), "#!/bin/sh\nexit 1\n")
      File.chmod(0o755, File.join(stub, 'gh'))
      Dir.mktmpdir { |root| return yield("#{stub}:#{ENV.fetch('PATH')}", root) }
    end
  end

  def silently
    original = [$stdout, $stderr]
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
  ensure
    $stdout, $stderr = original
  end
end
