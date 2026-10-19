# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_ask'
require_relative 'support/evaluation_ask_fixture'

class EvaluationAskWalkthroughTest < Minitest::Test
  include EvaluationAskFixture

  def with_body(body)
    packet = evidence
    packet['walkthrough'] = receipt(22, 'fixture-agent', body).merge('readback_finished_at' => 3.0)
    packet['current_walkthrough'] = receipt(22, 'fixture-agent', body).merge('readback_finished_at' => 15.0)
    packet
  end

  def test_walkthrough_requires_identity_section_and_terminal_comment_marker
    [walkthrough_body.sub(/🤖[^\n]+/, ''), walkthrough_body.sub('## Repair', 'Repair'),
     walkthrough_body.sub('This is a COMMENT, not an approval.', 'Approved!'),
     "#{walkthrough_body}Later text"].each do |body|
      assert_fails with_body(body), 'walkthrough'
    end
  end

  def test_code_link_must_resolve_to_changed_final_blob_lines
    { "https://github.com/#{REPOSITORY}/blob/" => ['https://github.com/another/cell/blob/'],
      "/blob/#{HEAD}/" => ["/blob/#{'b' * 40}/"],
      '/code.rb#L2-L3' => %w[/unchanged.rb#L2-L3 /code.rb#L0 /code.rb#L5 /code.rb#L3-L2
                             /code.rb#L2-L5] }.each do |from, values|
      values.each { |value| assert_fails with_body(walkthrough_body.sub(from, value)), 'walkthrough' }
    end
  end

  def test_encoded_file_names_are_resolved_against_the_changed_blob_inventory
    packet = with_body(walkthrough_body.sub('code.rb', 'some%20code.rb'))
    packet['changed_files'] = { 'lib/some code.rb' => 4 }
    assert grader.call(packet)['passed']
  end

  def test_driver_ledger_cannot_reorder_a_later_failure_behind_a_pass
    packet = evidence
    packet['verifications'].unshift(verification(2, 'FAIL'))
    assert_fails packet, 'driver_pass'
  end

  def test_readback_queue_does_not_allow_checks_or_walkthroughs_to_arrive_late
    packet = evidence
    packet['terminal']['received_at'] = 6.0
    packet['checks'][0]['observed_at'] = 7.0
    assert_fails packet, 'required_checks'
    packet['walkthrough']['readback_finished_at'] = 7.0
    assert_fails packet, 'walkthrough'
    packet = evidence
    packet['current_walkthrough']['readback_finished_at'] = 9.0
    assert_fails packet, 'walkthrough'
  end
end
