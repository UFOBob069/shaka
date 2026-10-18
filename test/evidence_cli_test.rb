# frozen_string_literal: true

require_relative 'evidence_fixture'

class EvidenceCliTest < Minitest::Test
  include EvidenceFixture

  def test_help_exits_successfully
    capture_io { assert_equal 0, Shaka::Evidence::Command.run(%w[run --help]) }
    capture_io { assert_equal 0, Shaka::LocalReview.run(%w[check --help]) }
  end

  def test_run_reports_an_unconfigured_fixed_command
    with_checkout do |root, ref|
      _output, error = capture_io do
        assert_equal 1, Shaka::Evidence::Command.run(
          ['run', '--root', root, '--ref', ref, '--repository', 'shakacode/shaka', '--command', 'validate_local']
        )
      end
      assert_includes error, 'validate_local is not configured for this repository'
    end
  end

  def test_bind_rejects_result_inside_candidate_checkout
    with_checkout do |root, ref|
      path = File.join(root, 'result.json')
      File.write(path, JSON.generate(run_check(root, ref)))
      assert_raises(Shaka::Error) { Shaka::Evidence::Result.local_file!(root, path) }
    end
  end
end
