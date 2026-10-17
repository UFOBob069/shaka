# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require_relative 'support/evaluation_comparison_fixture'

class EvaluationComparisonCliTest < Minitest::Test
  include EvaluationComparisonFixture

  CLI = File.expand_path('../eval/bin/shaka-eval', __dir__)
  def test_cli_checks_matching_run_sets_without_a_release_verdict
    output, error, status = invoke(@baseline, @candidate)
    assert_predicate status, :success?, error
    assert_equal 'eligible', JSON.parse(output).fetch('status')
    refute_includes output, 'clean'
    refute_includes output, 'synthetic-machine'
    refute_includes output, '/synthetic/'
  end

  def test_provisional_and_refused_inputs_exit_unsuccessfully
    candidate['routed_model'] = 'UNKNOWN'
    assert_equal 1, invoke(@baseline, @candidate).last.exitstatus
    assert_equal 1, invoke(@baseline, []).last.exitstatus
  end

  def test_invalid_input_never_echoes_contents_or_paths
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'private-path.json')
      File.binwrite(path, "\xFFprivate-value".b)
      output, error, status = Open3.capture3('ruby', CLI, 'check-comparison', path, path, '--axis', 'skill')
      assert_equal 1, status.exitstatus
      assert_equal 'unreadable_or_invalid_json', JSON.parse(output).fetch('reason')
      refute_includes output + error, 'private-'
      assert_empty error
    end
  end

  private

  def invoke(baseline, candidate)
    Dir.mktmpdir do |dir|
      paths = [baseline, candidate].each_with_index.map do |records, index|
        File.join(dir, "#{index}.json").tap { File.write(it, JSON.generate(records)) }
      end
      Open3.capture3('ruby', CLI, 'check-comparison', *paths, '--axis', 'skill')
    end
  end
end
