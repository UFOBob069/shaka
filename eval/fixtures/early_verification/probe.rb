# frozen_string_literal: true

require 'json'
require File.expand_path('lib/receiver', ARGV.fetch(0))

ids = %w[a b c]
stream = ids.map { |id| "#{JSON.generate('id' => id)}\n" }.join
checked = 0
failure = nil

(0..stream.length).each do |first|
  (first..stream.length).each do |second|
    delivered = []
    receiver = Receiver.new { |id| delivered << id }
    consumed = +''

    begin
      [stream[0...first], stream[first...second], stream[second..]].each do |chunk|
        receiver.receive(chunk)
        consumed << chunk
        expected = ids.take(consumed.count("\n"))
        raise "expected #{expected.inspect}; got #{delivered.inspect}" unless delivered == expected

        checked += 1
      end
    rescue StandardError => e
      failure = { cuts: [first, second], error: "#{e.class}: #{e.message}" }
      break
    end
  end
  break if failure
end

puts JSON.generate(checks: checked, passed: failure.nil?, failure:)
exit(failure ? 1 : 0)
