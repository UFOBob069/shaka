# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/decision_replay'

class EvaluationDecisionReaderTest < Minitest::Test
  def setup = @directory = Dir.mktmpdir
  def teardown = FileUtils.remove_entry(@directory)

  def test_criteria_digest_binds_expected_actions_and_order
    a = Shaka::Evaluation::DecisionReplay.criteria(%w[handoff merge])
    assert_equal a, Shaka::Evaluation::DecisionReplay.criteria(%w[handoff merge])
    refute_equal a, Shaka::Evaluation::DecisionReplay.criteria(%w[merge handoff])
  end

  def test_reader_rejects_malformed_and_oversized_exports
    path = decision_path
    ['{', "\xff", ' ' * 65_537].each do |bytes|
      File.binwrite(path, bytes)
      assert_nil Shaka::Evaluation::DecisionReplay.read(@directory)
    end
  end

  def test_symlinked_file_cannot_supply_an_answer
    path = decision_path
    target = File.join(@directory, 'answer.json')
    File.write(target, '{"actions":["handoff"],"reason":"correct"}')
    File.symlink(target, path)
    assert_nil Shaka::Evaluation::DecisionReplay.read(@directory)
  end

  def test_symlinked_verifier_directory_cannot_supply_an_answer
    File.symlink(@directory, File.join(@directory, 'verifier'))
    File.write(File.join(@directory, 'decision.json'), '{"actions":["handoff"],"reason":"correct"}')
    assert_nil Shaka::Evaluation::DecisionReplay.read(@directory)
  end

  def test_invalid_decision_shapes_cannot_pass
    [nil, [], { 'actions' => ['handoff'] }, { 'actions' => ['invented'], 'reason' => 'unknown' }].each do |response|
      refute Shaka::Evaluation::DecisionReplay.grade(response, ['handoff']).first
    end
  end

  private

  def decision_path
    FileUtils.mkdir_p(File.join(@directory, 'verifier'))
    File.join(@directory, 'verifier/decision.json')
  end
end
