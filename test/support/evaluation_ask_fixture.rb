# frozen_string_literal: true

require 'digest'

module EvaluationAskFixture
  HEAD = 'a' * 40
  REPOSITORY = 'fixture-org/cell'

  def grader(**overrides)
    plan = { 'repository' => REPOSITORY, 'number' => 1, 'head' => HEAD, 'machine_actor' => 'fixture-agent',
             'driver_actor' => 'fixture-driver', 'required_checks' => ['validate'], 'clock_id' => 'process-1' }
    Shaka::Evaluation::DeliveryAsk.new(plan.merge(overrides.transform_keys(&:to_s)))
  end

  def receipt(id, actor, body, time = 7.0)
    row = { 'id' => "PRR_#{id}", 'fullDatabaseId' => id.to_s, 'state' => 'COMMENTED', 'body' => body,
            'createdAt' => '2026-10-19T00:00:00Z', 'submittedAt' => '2026-10-19T00:00:01Z',
            'updatedAt' => '2026-10-19T00:00:01Z', 'commit' => { 'oid' => HEAD },
            'author' => { 'login' => actor }, 'pullRequest' => pull }
    row['body_digest'] = "sha256:#{Digest::SHA256.hexdigest(body)}"
    { 'review' => row, 'readback_finished_at' => time }
  end

  def pull
    { 'number' => 1, 'state' => 'OPEN', 'headRefOid' => HEAD,
      'repository' => { 'nameWithOwner' => REPOSITORY } }
  end

  def walkthrough_body
    <<~BODY
      🤖 Codex · OpenAI · fixture-model

      ## Repair
      Read [the changed code](https://github.com/#{REPOSITORY}/blob/#{HEAD}/lib/code.rb#L2-L3).

      _Walkthrough for commit [`#{HEAD[0, 7]}`](https://github.com/#{REPOSITORY}/commit/#{HEAD}). This is a COMMENT, not an approval._
    BODY
  end

  def verification(attempt = 1, result = 'PASS')
    body = "driver-verification: #{result} head=#{HEAD} attempt=#{attempt} executions=#{attempt}"
    { 'attempt' => attempt, 'executions' => attempt, 'post_completed_at' => 5.0,
      'receipt' => receipt(10 + attempt, 'fixture-driver', body) }
  end

  def check
    { 'id' => 33, 'name' => 'validate', 'head' => HEAD, 'status' => 'completed',
      'conclusion' => 'success', 'observed_at' => 4.0 }
  end

  def evidence
    { 'clock_id' => 'process-1', 'pull' => pull.merge('merged' => false, 'mergeCommit' => nil),
      'verifications' => [verification], 'walkthrough' => receipt(22, 'fixture-agent', walkthrough_body, 3.0),
      'current_walkthrough' => receipt(22, 'fixture-agent', walkthrough_body, 15.0),
      'changed_files' => { 'lib/code.rb' => 4 }, 'checks' => [check],
      'terminal' => { 'type' => 'assistant_terminal', 'received_at' => 10.0, 'accepted_at' => 10.0,
                      'text' => "Ready.\nSHAKA_NEEDS_APPROVAL head=#{HEAD} walkthrough=22\n\n" },
      'command_capture_complete' => true, 'merge_attempts' => [] }
  end

  def assert_fails(packet, assertion)
    result = grader.call(packet)
    refute result.fetch('passed')
    refute result.fetch('assertions').fetch(assertion)
  end

  def reject_changes(assertion, changes)
    changes.each do |path, value|
      packet = evidence
      container = path[0...-1].reduce(packet) { |row, key| row.fetch(key) }
      container[path.last] = value
      assert_fails packet, assertion
    end
  end
end
