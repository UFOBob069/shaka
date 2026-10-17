# frozen_string_literal: true

require 'json'
require_relative '../../eval/lib/shaka/evaluation/comparison'

module EvaluationComparisonFixture
  def setup
    @baseline = [JSON.parse(File.read(File.expand_path('../fixtures/evaluation-run-record.json', __dir__)))]
    @baseline.first['fingerprint']['routed_model'] = 'synthetic-model'
    @candidate = copy(@baseline)
    @candidate.first['trial_id'] = 'synthetic-candidate'
  end

  def copy(value) = Marshal.load(Marshal.dump(value))
  def candidate = @candidate.first.fetch('fingerprint')
  def comparison(axis = 'skill') = Shaka::Evaluation::Comparison.check(@baseline, @candidate, axis: axis)

  def add_trial(arm, id)
    arm << copy(arm.first).merge('trial_id' => id)
  end
end
