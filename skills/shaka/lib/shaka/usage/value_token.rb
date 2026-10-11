# frozen_string_literal: true

module Shaka
  # Publication values allow plain tokens or one provider/model slug, never URLs.
  module UsageValue
    TOKEN = /\A[a-zA-Z0-9][a-zA-Z0-9._:-]{0,79}\z/
    SLUG = %r{\A[a-zA-Z0-9][a-zA-Z0-9_-]*/[a-zA-Z0-9][a-zA-Z0-9._:-]*\z}

    def self.token(value)
      return unless value.is_a?(String) && value.valid_encoding? && value.length <= 80
      return if /\Awww\./i.match?(value)

      value if TOKEN.match?(value) || SLUG.match?(value)
    end
  end
end
