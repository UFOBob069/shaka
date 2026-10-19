# frozen_string_literal: true

require_relative '../evidence/machine_facts'

module Shaka
  # Says how long a recorded check took and on what kind of machine, such as
  # "27m on m5 (Apple M5 Max, 18 cores, 128 GB RAM, 3 GB free, load 140→450)", so a reader
  # comparing runs can see the hardware and how busy it was. Unknown facts are left out.
  module RunSummary
    module_function

    def render(result)
      milliseconds = result['duration_ms'] if result.is_a?(Hash)
      return unless milliseconds.is_a?(Integer) && !milliseconds.negative?

      facts = known(result['machine'])
      details = machine(facts)
      [duration(milliseconds), ("on #{facts['alias']}" if facts['alias']),
       ("(#{details.join(', ')})" unless details.empty?)].compact.join(' ')
    end

    def known(machine) = Evidence::MachineFacts.sanitize(machine).reject { |_field, value| value == 'UNKNOWN' }

    def duration(milliseconds)
      seconds = (milliseconds / 1000.0).round
      return "#{seconds}s" if seconds < 60

      minutes, rest = seconds.divmod(60)
      return "#{minutes}m #{rest}s" if minutes < 10

      rounded = (seconds / 60.0).round
      return "#{rounded}m" if rounded < 60

      hours, minutes = rounded.divmod(60)
      "#{hours}h #{minutes}m"
    end

    def machine(facts)
      cpu, cores, total, free = facts.values_at('cpu_model', 'cpu_cores', 'memory_total_gb', 'memory_free_gb_at_start')
      [cpu, ("#{cores} cores" if cores), ("#{total} GB RAM" if total), ("#{free} GB free" if free),
       load(facts['load_at_start'], facts['load_at_end'])].compact
    end

    def load(start, finish)
      shown = [start, finish].compact.map { |value| value >= 10 ? value.round.to_s : value.round(1).to_s }
      "load #{shown.uniq.size == 1 ? shown.first : shown.join('→')}" unless shown.empty?
    end
  end
end
