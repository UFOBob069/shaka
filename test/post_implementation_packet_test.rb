# frozen_string_literal: true

require_relative 'support/post_implementation_fixture'

# The checkpoint runs on the description content and returns a verification verdict.
class PostImplementationPacketTest < Minitest::Test
  include PostImplementationFixture

  def own(**changes) = CHECKPOINT_CONTENT.merge('checkpoint' => CHECKPOINT_CONTENT['checkpoint'].merge(changes))

  def reviewer_packet(root)
    JSON.parse(checkpoint_trace(root).fetch('prompt')[/--- BEGIN PACKET DATA \h+ ---\n(.*?)\n--- END PACKET DATA/m, 1])
  end

  def test_the_description_content_reaches_the_reviewer_with_the_adequacy_contract
    with_repository do |root, base, head, bin|
      fake_checkpoint(bin, head)
      result, status = run_checkpoint(root, base, head, bin)

      assert_predicate status, :success?, result.inspect
      packet = reviewer_packet(root)
      assert_equal [%w[summary intent verification audience repair_history], INTENT], [packet.keys, packet['intent']]
      assert_includes checkpoint_trace(root).fetch('prompt'), 'verification_adequacy'
    end
  end

  def test_the_completed_report_keeps_the_verification_verdict
    with_repository do |root, base, head, bin|
      fake_checkpoint(bin, head)
      result, = run_checkpoint(root, base, head, bin)
      assert_equal 'adequate', JSON.parse(File.read(result.fetch('report'))).dig('verification_adequacy', 'verdict')
    end
  end

  def test_content_written_twice_or_missing_its_proof_stops_before_invocation
    [CHECKPOINT_CONTENT.merge('problem' => 'Restated'), CHECKPOINT_CONTENT.except('checkpoint'),
     CHECKPOINT_CONTENT.merge('checkpoint' => { 'audience' => 'Maintainers' }),
     CHECKPOINT_CONTENT.merge('verification' => VERIFICATION.merge('checks' => [])),
     CHECKPOINT_CONTENT.merge('intent' => INTENT.except('safe_because')),
     CHECKPOINT_CONTENT.except('summary'), own('evidence' => [''])].each do |packet|
      assert_refused_before_invocation(packet)
    end
  end

  def assert_refused_before_invocation(packet)
    @packet = packet
    with_repository do |root, base, head, bin|
      fake_checkpoint(bin, head)
      result, status = run_checkpoint(root, base, head, bin)

      refute_predicate status, :success?
      assert_equal 'setup_failure', result.fetch('failure_stage'), result.inspect
      refute_path_exists File.join(root, 'trace.json')
    end
  end

  def test_a_repository_prompt_keeps_the_packaged_verdict_definitions
    settings = { 'post_implementation' => { 'prompt_file' => '.agents/codex-prompt.md' } }
    with_repository(settings) do |root, base, head, bin|
      fake_checkpoint(bin, head)
      _, status = run_checkpoint(root, base, head, bin)
      prompt = checkpoint_trace(root).fetch('prompt')
      assert_predicate status, :success?
      assert prompt.start_with?('Codex-only instructions')
      assert_includes prompt, '- `inadequate`: no check reaches the fact the safety claim rests on.'
    end
  end

  def test_checkpoint_evidence_reaches_the_reviewer
    @packet = own('evidence' => ['Growth: +40 words'])
    with_repository do |root, base, head, bin|
      fake_checkpoint(bin, head)
      _, status = run_checkpoint(root, base, head, bin)
      assert_predicate status, :success?
      assert_equal ['Growth: +40 words'], reviewer_packet(root)['evidence']
    end
  end

  def test_a_report_without_a_verification_verdict_does_not_complete
    with_repository do |root, base, head, bin|
      report = { head:, conclusion: 'Proceed', reasons: ['Useful'], concerns: [], alternative: 'None' }
      write_executable(bin, 'codex', "#!/usr/bin/env ruby\nrequire 'json'\n" \
                                     "File.write(ARGV[ARGV.index('-o')+1], #{JSON.generate(report).dump})\n")
      result, status = run_checkpoint(root, base, head, bin)

      refute_predicate status, :success?
      assert_equal 'report_validation', result.fetch('failure_stage')
    end
  end
end
