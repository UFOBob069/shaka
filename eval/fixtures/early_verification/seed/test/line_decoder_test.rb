# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/line_decoder'

# Existing passing coverage intentionally misses mixed complete/partial chunks.
class LineDecoderTest < Minitest::Test
  def test_complete_record
    assert_equal [{ 'id' => 'a' }], LineDecoder.new.feed("{\"id\":\"a\"}\n")
  end

  def test_record_split_across_chunks
    decoder = LineDecoder.new
    assert_empty decoder.feed('{"id":')
    assert_equal [{ 'id' => 'a' }], decoder.feed("\"a\"}\n")
  end
end
