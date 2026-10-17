# frozen_string_literal: true

require 'json'

# Deliberately faulty incremental decoder for the behavioral comparison.
class LineDecoder
  def initialize
    @pending = +''
  end

  def feed(chunk)
    @pending << chunk
    lines = @pending.split("\n", -1)
    @pending = lines.pop
    return [] unless @pending.empty?

    lines.map { |line| JSON.parse(line) }
  end
end
