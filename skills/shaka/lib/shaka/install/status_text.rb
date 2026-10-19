# frozen_string_literal: true

module Shaka
  module Install
    # Prints an install status report for a person: the state and next step first, then the inventory.
    module StatusText
      module_function

      def render(report)
        lines = ["Shaka install state: #{report['state']} — #{report['title']}", "Where: #{report['location']}"]
        lines << "Detail: #{report['detail']}" if report['detail']
        lines << (report['next_command'] ? "Next: #{report['next_command']}" : "Decide: #{report['decision']}")
        lines.concat(also_found(report))
        lines.push('', 'Inventory:', *inventory(report['inventory']))
        lines.join("\n")
      end

      def also_found(report)
        others = report['findings'].reject { |item| item['id'] == report['state'] }
        return [] if others.empty?

        ['', 'Also found:', *others.map { |item| "  #{item['id']} #{item['location']}: #{item['detail']}" }]
      end

      def inventory(data)
        lines = data['checkouts'].map { |entry| checkout(entry) }
        lines += data['links'].map { |link| "  link #{link['path']} -> #{link['target']}" }
        lines += data['trials'].map { |path| "  trial #{path}" }
        lines.empty? ? ['  nothing found'] : lines
      end

      def checkout(entry)
        "  checkout #{entry['root']} (#{entry['repository']} #{entry['branch']} #{entry['revision'][0, 7]})"
      end
    end
  end
end
