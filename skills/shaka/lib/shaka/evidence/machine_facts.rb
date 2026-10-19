# frozen_string_literal: true

require 'etc'
require 'open3'
require 'rbconfig'
require_relative '../doctor/machine_alias'

module Shaka
  module Evidence
    # Records what kind of machine ran a check and how busy it was, so a slow run can be told
    # apart from slow hardware. The result is published, so only these coarse fields enter it:
    # never a host name, serial number, user name, or path. A field that cannot be read is
    # UNKNOWN; reading never fails the check.
    module MachineFacts
      UNKNOWN = 'UNKNOWN'
      # The brand string is the one free-text value; anything outside plain ASCII words is dropped.
      CPU_MODEL = /\A[A-Za-z0-9][A-Za-z0-9 ()@.,+_-]{0,79}\z/
      GIGABYTE = 1024**3
      COUNT = ->(value) { value.is_a?(Integer) && value.positive? }
      LOAD = ->(value) { value.is_a?(Numeric) && value.finite? && value >= 0 }
      # The shape each published field must have.
      SHAPES = { 'alias' => ->(value) { value.is_a?(String) && ExecutionProvenance::SAFE_VALUE.match?(value) },
                 'cpu_model' => ->(value) { value.is_a?(String) && CPU_MODEL.match?(value) },
                 'cpu_cores' => COUNT, 'memory_total_gb' => COUNT,
                 'memory_free_gb_at_start' => ->(value) { value.is_a?(Integer) && value >= 0 },
                 'load_at_start' => LOAD, 'load_at_end' => LOAD }.freeze
      FIELDS = SHAPES.keys.freeze

      module_function

      # Runs a timed block, which returns its value and timing record, and adds the machine to that
      # record: the facts from just before the block and the load just after it.
      def measure(environment: ENV, reader: Reader.new)
        facts = start(environment:, reader:)
        value, record = yield
        [value, record.merge('machine' => facts.merge('load_at_end' => guarded { reader.load }))]
      end

      def start(environment:, reader:)
        { 'alias' => guarded { Doctor::MachineAlias.publishable(environment) },
          'cpu_model' => guarded { cpu_model(reader.cpu_model) },
          'cpu_cores' => guarded { reader.cores },
          'memory_total_gb' => guarded { gigabytes(reader.memory_total) },
          'memory_free_gb_at_start' => guarded { gigabytes(reader.memory_free) },
          'load_at_start' => guarded { reader.load } }
      end

      # A result file is local and editable, so publication accepts only values of the recorded shape.
      def sanitize(facts)
        facts = {} unless facts.is_a?(Hash)
        SHAPES.to_h { |field, shape| [field, shape.call(facts[field]) ? facts[field] : UNKNOWN] }
      end

      def guarded
        value = yield
        value.nil? ? UNKNOWN : value
      rescue StandardError
        UNKNOWN
      end

      def cpu_model(text)
        model = text.to_s.split.join(' ')
        model if CPU_MODEL.match?(model)
      end

      def gigabytes(bytes) = (bytes.fdiv(GIGABYTE).round if COUNT.call(bytes))

      # Reads the operating system's own counters: sysctl and vm_stat on macOS, /proc on Linux.
      # Tools run from their system paths, so neither PATH nor the candidate checkout chooses them.
      # Each method returns nil when the value is unavailable on this platform.
      class Reader
        def initialize(platform: RbConfig::CONFIG['host_os'], proc_root: '/proc', command: nil)
          @platform = platform
          @proc_root = proc_root
          @command = command || ->(*arguments) { capture(*arguments) }
        end

        # Processors this process may use, which a container or affinity mask can lower.
        def cores = Etc.nprocessors

        def cpu_model
          return sysctl('machdep.cpu.brand_string') if mac?

          proc_field('cpuinfo', 'model name', separator: ':') if linux?
        end

        def memory_total
          return integer(sysctl('hw.memsize')) if mac?

          kilobytes('MemTotal') if linux?
        end

        # Memory a new process could use without swapping: free plus reclaimable pages, which
        # is what Linux reports as MemAvailable. macOS keeps little memory strictly free.
        def memory_free
          return mac_available if mac?

          kilobytes('MemAvailable') if linux?
        end

        # The one-minute load average.
        def load
          text = mac? ? sysctl('vm.loadavg').to_s.delete('{}') : (read('loadavg') if linux?)
          number = Float(text.to_s.split.first, exception: false)
          number.round(1) if number&.finite? && number >= 0
        end

        private

        def mac? = @platform.to_s.include?('darwin')

        def linux? = @platform.to_s.include?('linux')

        def sysctl(name) = @command.call('/usr/sbin/sysctl', '-n', name)&.strip

        def mac_available
          output = @command.call('/usr/bin/vm_stat').to_s
          page = integer(output[/page size of (\d+) bytes/, 1])
          pages = ['Pages free', 'Pages inactive', 'Pages speculative'].map do |label|
            integer(output[/^#{label}:\s+(\d+)\./, 1])
          end
          page * pages.sum if page && pages.all?
        end

        def kilobytes(label)
          value = integer(proc_field('meminfo', label, separator: ':').to_s[/\A(\d+) kB\z/, 1])
          value * 1024 if value
        end

        def proc_field(file, label, separator:)
          line = read(file).to_s.lines.find { |entry| entry.split(separator, 2).first.to_s.strip == label }
          line.split(separator, 2).last.strip if line
        end

        def read(file) = File.read(File.join(@proc_root, file), encoding: 'UTF-8')

        def integer(text) = Integer(text.to_s, 10, exception: false)

        def capture(*)
          output, _error, status = Open3.capture3(*)
          output if status.success?
        rescue SystemCallError
          nil
        end
      end
    end
  end
end
