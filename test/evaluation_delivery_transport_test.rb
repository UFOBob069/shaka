# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_readback'
require_relative 'support/evaluation_delivery_fixture'

class EvaluationDeliveryTransportTest < Minitest::Test
  include EvaluationDeliveryFixture

  def test_failed_or_deleted_review_is_not_unchanged_and_does_not_expose_stderr
    receipt = capture
    File.write(@response, 'failure')
    refute reader.unchanged?(receipt)
    error = assert_raises(IOError) { capture }
    refute_includes error.message, 'private-error'
  end

  def test_malformed_or_partial_json_is_not_a_receipt
    ['not-json', "\xff".b, JSON.generate({ data: { node: review }, errors: [{ message: 'partial' }] })].each do |bytes|
      File.binwrite(@response, bytes)
      assert_raises(IOError) { capture }
    end
  end

  def test_oversized_api_response_is_refused
    File.write(@response, 'x' * 1_048_577)
    assert_raises(IOError) { capture }
  end

  def test_deadline_terminates_and_reaps_the_native_child
    File.write(@response, 'hang')
    assert_raises(IOError) { reader(seconds: 2).read(node_id: NODE, review_id: 5_566_107_686, actor: 'fixture-agent') }
    pid = Integer(File.read(File.join(@directory, 'pid')), 10)
    assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
  end
end
