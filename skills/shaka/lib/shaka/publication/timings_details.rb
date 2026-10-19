# frozen_string_literal: true

require_relative '../error'
require_relative 'timing_stretches'

module Shaka
  # Renders the time between checkpoints and how long each checkpoint waited on a person.
  class TimingsDetails
    SUMMARY = 'Timings'
    UNAVAILABLE = 'GitHub did not supply the timeline; the next update tries again.'
    OPEN = ['still waiting', 'this update'].freeze
    GUIDE = '[Understand the timings](https://shaka.shakacode.com/docs/reference/timings).'
    LEGEND = 'Times are UTC wall-clock time. A wait runs from when an attention label goes on until it ' \
             'comes off or the pull request merges or closes.'
    # Thirty rows keep the body far below GitHub's size limit however often a pull request waits.
    MAX_ROWS = 30

    def self.refuse_free_form!(items)
      return unless items.any? { |item| item.is_a?(Hash) && item['summary'].to_s.strip.match?(/\Atimings\b/i) }

      raise Error, 'Publication timings are read from the pull request timeline, not supplied as a details item.'
    end

    def self.for(timeline) = timeline ? [new(timeline).detail] : []

    def initialize(timeline, now: Time.now.utc)
      @timeline = timeline
      @now = now.utc
    end

    def detail
      # The reason can quote gh output, so it stays out of the public body.
      return { 'summary' => SUMMARY, 'body' => UNAVAILABLE } if @timeline.key?('unavailable')

      rows = TimingStretches.new(@timeline, @now).rows
      body = [totals(rows), table(rows.last(MAX_ROWS)), omitted(rows), LEGEND, GUIDE].compact.join("\n\n")
      # A collapsed summary counts as visible description prose, so the totals stay inside.
      { 'summary' => SUMMARY, 'body' => body }
    end

    private

    def totals(rows)
      waited = rows.select { |row| row[:wait] }
      parts = ["#{duration(total(rows.reject { |row| row[:wait] }))} between checkpoints"]
      parts << "#{duration(total(waited))} waiting on a person in #{count(waited.size)}" unless waited.empty?
      "**Totals:** #{parts.join(' · ')}"
    end

    def omitted(rows)
      return if rows.size <= MAX_ROWS

      "Showing the latest #{MAX_ROWS} of #{rows.size} stretches; the totals include all of them."
    end

    def count(waits) = waits == 1 ? '1 wait' : "#{waits} waits"
    def total(rows) = rows.sum { |row| row[:to] - row[:from] }

    def table(rows)
      lines = ['| Stretch | From | To | Time |', '| --- | --- | --- | ---: |']
      lines.concat(rows.map { |row| "| #{[row[:name], clock(row[:from]), to_cell(row), length(row)].join(' | ')} |" })
      lines.join("\n")
    end

    def to_cell(row) = row[:ending] ? "#{clock(row[:to])} (#{row[:ending]})" : clock(row[:to])
    # A stretch still running when this update rendered keeps growing until the next one.
    def length(row) = "#{duration(row[:to] - row[:from])}#{' so far' if OPEN.include?(row[:ending])}"
    def clock(time) = time.strftime('%Y-%m-%d %H:%M')

    def duration(seconds)
      minutes = (seconds / 60).floor
      return '<1m' if minutes < 1
      return "#{minutes}m" if minutes < 60

      hours, minutes = minutes.divmod(60)
      return "#{hours}h #{minutes}m" if hours < 24

      days, hours = hours.divmod(24)
      "#{days}d #{hours}h"
    end
  end
end
