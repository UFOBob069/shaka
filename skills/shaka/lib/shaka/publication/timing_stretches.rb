# frozen_string_literal: true

require_relative '../attention'

module Shaka
  # Divides a pull request's life into the time between checkpoints and each wait on a person.
  class TimingStretches
    BETWEEN = 'Between checkpoints'
    WAITS = Attention::LABELS.to_h { |state, label| [label, state == 'merge' ? 'merge approval' : state] }.freeze

    def initialize(timeline, now)
      @timeline = timeline
      @now = now
      @opened = timeline.fetch('opened').utc
      @finished = (timeline['merged'] || timeline['closed'])&.utc
    end

    # Each row is a hash with name, from, to, an ending note or nil, and whether it is a wait.
    def rows
      rows = before_opening
      cursor = @opened
      waits.each do |wait|
        rows << stretch(BETWEEN, cursor, wait[:from]) if wait[:from] > cursor
        rows << wait
        cursor = wait[:to]
      end
      rows << last_stretch(cursor) if (@finished || @now) > cursor
      rows
    end

    private

    # A rebase can date the first commit after the pull request opened; then there is no earlier stretch.
    def before_opening
      first = @timeline['first_commit']&.utc
      first && first < @opened ? [stretch('Before the pull request', first, @opened, 'opened')] : []
    end

    def last_stretch(cursor)
      return stretch(BETWEEN, cursor, @now, 'this update') unless @finished

      stretch(BETWEEN, cursor, @finished, outcome)
    end

    def outcome = @timeline['merged'] ? 'merged' : 'closed'
    def stretch(name, from, to, ending = nil) = { name:, from:, to:, ending:, wait: false }

    # Overlapping attention labels are one wait, which ends when the last of them comes off.
    def waits
      @active = []
      @found = []
      @current = nil
      @timeline.fetch('labels').each do |event|
        at = event.fetch('at').utc
        break if @finished && at >= @finished

        apply(event, at)
      end
      close_open_wait
      @found
    end

    def close_open_wait
      @found << close(@current, @finished || @now, @finished ? outcome : 'still waiting') if @current
    end

    def apply(event, at)
      name = event.fetch('name')
      return start(name, at) if event.fetch('added')

      @active.delete(name)
      finish(at)
    end

    def start(name, at)
      @active |= [name]
      @current ||= { from: at, names: [] }
      @current[:names] |= [name]
    end

    def finish(at)
      return unless @current && @active.empty?

      @found << close(@current, at, 'resumed')
      @current = nil
    end

    def close(wait, at, ending)
      labels = wait[:names].map { |name| WAITS.fetch(name, name) }.join(' and ')
      { name: "Waiting on a person: #{labels}", from: wait[:from], to: at, ending:, wait: true }
    end
  end
end
