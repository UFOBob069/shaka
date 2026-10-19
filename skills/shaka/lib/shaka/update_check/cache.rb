# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'

module Shaka
  class UpdateCheck
    # The last update-check answer for one registered checkout, kept so later helper calls can
    # repeat it without a network request. One file serves the machine; it names its checkout.
    module Cache
      SECONDS = 24 * 60 * 60

      module_function

      # The real path, so a checkout reached through a link or /var on macOS keeps one entry.
      def key(checkout) = File.realpath(checkout)

      def path(home) = File.join(home, '.local', 'share', 'shaka', 'update-check.json')

      # The entry for this checkout, or an empty one when the file is missing, unreadable, or another checkout's.
      def read(checkout, home:)
        entry = JSON.parse(File.read(path(home)))
        entry.is_a?(Hash) && entry['checkout'] == key(checkout) ? entry : {}
      rescue SystemCallError, JSON::ParserError
        {}
      end

      # Keeps the last notice time, so a new answer does not repeat a notice shown today.
      def record(checkout, result, home: nil, now: Time.now)
        home ||= Dir.home
        noticed = read(checkout, home:).slice('noticed_at')
        write(home, { 'checkout' => key(checkout), 'checked_at' => now.utc.iso8601, 'result' => result, **noticed })
      rescue SystemCallError, ArgumentError => e
        warn "Shaka update check not cached: #{e.message}"
      end

      # False when the time cannot be saved: a notice that cannot be limited to once a day is not shown.
      def noticed(entry, checkout, home:, now: Time.now)
        write(home, entry.merge('checkout' => key(checkout), 'noticed_at' => now.utc.iso8601))
        true
      rescue SystemCallError
        false
      end

      def fresh?(time, now)
        now - Time.iso8601(time.to_s) < SECONDS
      rescue ArgumentError
        false
      end

      def write(home, entry)
        target = path(home)
        FileUtils.mkdir_p(File.dirname(target), mode: 0o700)
        temporary = "#{target}.#{Process.pid}"
        File.write(temporary, "#{JSON.generate(entry)}\n", perm: 0o600)
        File.rename(temporary, target)
      ensure
        File.unlink(temporary) if temporary && File.exist?(temporary)
      end
    end
  end
end
