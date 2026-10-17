# frozen_string_literal: true

require_relative 'line_decoder'

# The transport boundary delivers each decoded record to its subscriber.
class Receiver
  def initialize(&deliver)
    @decoder = LineDecoder.new
    @deliver = deliver
  end

  def receive(chunk)
    @decoder.feed(chunk).each { |record| @deliver.call(record.fetch('id')) }
  end
end
