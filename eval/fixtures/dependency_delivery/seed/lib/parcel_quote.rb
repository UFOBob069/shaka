module ParcelQuote
  BASE_CENTS_PER_KG = 250

  # Each rule receives the parcel hash and returns the cents it adds.
  SURCHARGES = {
    oversize: ->(parcel) { parcel.fetch(:longest_side_cm, 0) > 120 ? 1500 : 0 }
  }.freeze

  def self.total_cents(parcel)
    weight = parcel.fetch(:weight_kg)
    raise ArgumentError, 'weight must be positive' unless weight.positive?

    (weight * BASE_CENTS_PER_KG).round + SURCHARGES.sum { |_name, rule| rule.call(parcel) }
  end
end
