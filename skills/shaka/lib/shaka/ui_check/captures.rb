# frozen_string_literal: true

require_relative '../error'

module Shaka
  module UiCheck
    # The uploaded captures a UI check shows, read from its Markdown.
    module Captures
      URL = %r{https://github\.com/(?:user-attachments/assets|[\w.-]+/[\w.-]+/assets/\d+)/[\w-]+}

      module_function

      def urls(body) = body.to_s.scan(URL).uniq

      # Every capture an open earlier check shows stays visible unless the new check
      # shows it too or the agent retires it, so folding never hides current evidence.
      def missing(earlier, body, retired)
        shown = urls(body)
        unknown = retired - earlier
        raise Error, "Retired captures are not in an open earlier UI check: #{unknown.join(', ')}" if unknown.any?

        earlier - shown - retired
      end

      # Each "PATH#ALT TEXT" names a local file for gh to upload.
      def paths(captures)
        captures.map do |capture|
          raise Error, 'Each UI check capture must be a "PATH#ALT TEXT" string.' unless capture.is_a?(String)

          path = capture.split('#', 2).first
          readable = File.file?(path) && File.readable?(path)
          raise Error, "UI check capture is not a readable file: #{path}" unless readable

          path
        end
      end
    end
  end
end
