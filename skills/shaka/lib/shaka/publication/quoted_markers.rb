# frozen_string_literal: true

require_relative '../error'
require_relative 'human_comments'

module Shaka
  # Shaka finds its regions by reading its own HTML-comment markers back from the body,
  # so supplied description text that quotes one would leave the next read ambiguous.
  module QuotedMarkers
    MARKER = %r{<!--\s*/?shaka:[\w:.-]*}

    module_function

    # Carried usage blocks come from a body carry already checked, and hold markers by design.
    # Human comments are GitHub's raw read; their excerpts drop HTML comments before rendering.
    def refuse!(content)
      usage = content['usage']
      supplied = content.except(HumanComments::KEY)
      walk(usage.is_a?(Hash) ? supplied.merge('usage' => usage.except('carried')) : supplied, 'content')
    end

    def walk(value, path)
      case value
      when Hash then value.each { |key, item| walk(item, "#{path}.#{key}") }
      when Array then value.each_with_index { |item, index| walk(item, "#{path}[#{index}]") }
      when String then refuse_string(value, path)
      end
    end

    def refuse_string(text, path)
      quoted = text[MARKER] or return

      name = quoted.sub(/\A<!--\s*/, '')
      raise Error, "#{path.delete_prefix('content.')} quotes the Shaka marker `#{quoted}`; Shaka reads that " \
                   "marker back from the pull request body. Name it without `<!--`, such as `#{name}`."
    end
  end
end
