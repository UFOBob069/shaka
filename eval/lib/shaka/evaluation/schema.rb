# frozen_string_literal: true

module Shaka
  module Evaluation
    # Only the JSON Schema vocabulary used by the bundled record contract.
    class Schema
      TYPES = {
        'object' => ->(v) { v.is_a?(Hash) }, 'array' => ->(v) { v.is_a?(Array) },
        'string' => ->(v) { v.is_a?(String) }, 'null' => lambda(&:nil?),
        'boolean' => ->(v) { [true, false].include?(v) },
        'number' => ->(v) { v.is_a?(Numeric) && v.finite? },
        'integer' => ->(v) { v.is_a?(Numeric) && v.finite? && v == v.to_i }
      }.freeze
      CHECKS = {
        'type' => ->(v, types) { Array(types).any? { |type| TYPES.fetch(type).call(v) } },
        'const' => ->(v, expected) { v == expected }, 'enum' => ->(v, values) { values.include?(v) },
        'minimum' => ->(v, n) { !v.is_a?(Numeric) || (v.finite? && v >= n) },
        'maximum' => ->(v, n) { !v.is_a?(Numeric) || (v.finite? && v <= n) },
        'minLength' => ->(v, n) { !v.is_a?(String) || v.length >= n },
        'maxLength' => ->(v, n) { !v.is_a?(String) || v.length <= n },
        'pattern' => ->(v, pattern) { !v.is_a?(String) || Regexp.new(pattern).match?(v) }
      }.freeze
      KEYWORDS = (CHECKS.keys + %w[$schema $id title $defs $ref anyOf required properties
                                   additionalProperties items]).freeze

      def initialize(document)
        @document = document
        check_rule(document)
      end

      def errors(value, rule = @document, path = '$')
        checks(value, rule, path) + forms(value, rule, path) +
          object_errors(value, rule, path) + array_errors(value, rule, path)
      end

      private

      def checks(value, rule, path)
        CHECKS.filter_map do |name, check|
          "#{path}: failed #{name}" if rule.key?(name) && !check.call(value, rule[name])
        end
      end

      def forms(value, rule, path)
        messages = rule['$ref'] ? errors(value, reference(rule['$ref']), path) : []
        messages << "#{path}: no matching form" if rule['anyOf']&.none? { errors(value, it).empty? }
        messages
      end

      def check_rule(rule)
        raise ArgumentError, 'Unsupported schema keyword' unless (rule.keys - KEYWORDS).empty?

        reference(rule['$ref']) if rule['$ref']
        children(rule).each { check_rule(it) }
      end

      def children(rule)
        rule.fetch('$defs', {}).values + rule.fetch('properties', {}).values + rule.fetch('anyOf', []) +
          [rule['items'], rule['additionalProperties']].grep(Hash)
      end

      def reference(ref)
        raise ArgumentError, 'Only local definition references are supported' unless ref.match?(%r{\A#/\$defs/[^/]+\z})

        @document.fetch('$defs').fetch(ref.delete_prefix('#/$defs/'))
      end

      def object_errors(value, rule, path)
        return [] unless value.is_a?(Hash)

        missing = (rule.fetch('required', []) - value.keys).map { "#{path}.#{it}: missing" }
        extra = value.keys - rule.fetch('properties', {}).keys
        missing << "#{path}: unexpected properties" if rule['additionalProperties'] == false && !extra.empty?
        missing + property_errors(value, rule, path)
      end

      def property_errors(value, rule, path)
        properties = rule.fetch('properties', {})
        value.flat_map do |key, entry|
          child = properties.fetch(key, rule['additionalProperties'])
          label = properties.key?(key) ? key : '*'
          child.is_a?(Hash) ? errors(entry, child, "#{path}.#{label}") : []
        end
      end

      def array_errors(value, rule, path)
        return [] unless value.is_a?(Array) && rule['items']

        value.each_with_index.flat_map { |entry, index| errors(entry, rule['items'], "#{path}[#{index}]") }
      end
    end
  end
end
