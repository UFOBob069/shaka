require 'minitest/autorun'
require_relative '../lib/parcel_quote'

class ParcelQuoteTest < Minitest::Test
  def test_prices_weight_and_registered_surcharges
    assert_equal '6.0.6', Gem.loaded_specs.fetch('minitest').version.to_s
    assert_equal 500, ParcelQuote.total_cents(weight_kg: 2)
    assert_equal 2000, ParcelQuote.total_cents(weight_kg: 2, longest_side_cm: 150)
    assert_raises(ArgumentError) { ParcelQuote.total_cents(weight_kg: 0) }
  end
end
