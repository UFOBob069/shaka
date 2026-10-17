# frozen_string_literal: true

require 'json'

module EvaluationBudgetFixture
  def setup
    @directory = Dir.mktmpdir
    @now = Time.utc(2026, 10, 16, 20)
    @limits = { 'monthly' => 200, 'nightly' => 5, 'pr' => 15 }
    @record = JSON.parse(File.read(File.expand_path('../fixtures/evaluation-run-record.json', __dir__)))
  end

  def teardown = FileUtils.remove_entry(@directory)

  def budget(**)
    Shaka::Evaluation::Budget.new(directory: File.join(@directory, 'budget'), limits: @limits,
                                  kind: 'nightly', clock: -> { @now }, **)
  end

  def record(task, id, cost = 1)
    copy = Marshal.load(Marshal.dump(@record))
    copy['trial_id'] = id
    copy['task'] = task
    copy['usage']['cache_neutral_dollars'] = cost
    copy
  end

  def settle(account, id, cost)
    account.settle(id: id, dollars: cost, digest: "sha256:#{'a' * 64}")
  end

  def saved_records = Dir.glob(File.join(@directory, 'records/*.json'))

  def runner(account = budget)
    Shaka::Evaluation::Runner.new(budget: account, directory: File.join(@directory, 'records'))
  end

  def tasks(count = 1) = Array.new(count) { @record.fetch('task').dup }
end
