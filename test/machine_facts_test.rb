# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/evidence/machine_facts'
require 'shaka/publication/run_summary'
require_relative 'settings_snapshot_helper'

# What vm_stat prints on macOS: 4 GB free, inactive, or speculative.
MAC_VM_STAT = <<~TEXT
  Mach Virtual Memory Statistics: (page size of 16384 bytes)
  Pages free:                                    65536.
  Pages active:                                2313179.
  Pages inactive:                               131072.
  Pages speculative:                             65536.
TEXT

class MachineFactsTest < Minitest::Test
  include EvidenceFixture
  include SettingsSnapshotHelper

  Facts = Shaka::Evidence::MachineFacts
  MAC = { %w[/usr/sbin/sysctl -n machdep.cpu.brand_string] => "Apple M5 Max\n",
          %w[/usr/sbin/sysctl -n hw.memsize] => "137438953472\n",
          %w[/usr/sbin/sysctl -n vm.loadavg] => "{ 140.25 120.5 100.0 }\n", %w[/usr/bin/vm_stat] => MAC_VM_STAT }.freeze

  def test_macos_reads_model_memory_and_load_from_sysctl_and_vm_stat
    reader = Facts::Reader.new(platform: 'darwin23', command: ->(*arguments) { MAC[arguments] })
    facts = Facts.start(environment: {}, reader:)
    assert_equal 'Apple M5 Max', facts['cpu_model']
    assert_equal 128, facts['memory_total_gb']
    assert_equal 4, facts['memory_free_gb_at_start']
    assert_in_delta 140.3, facts['load_at_start']
  end

  def test_linux_reads_proc
    with_proc(cpuinfo: "processor\t: 0\nmodel name\t: AMD EPYC 7763 64-Core Processor\n",
              meminfo: "MemTotal:       65843200 kB\nMemFree:  1 kB\nMemAvailable:   10485760 kB\n",
              loadavg: "3.50 2.00 1.00 2/300 999\n") do |reader|
      facts = Facts.start(environment: {}, reader:)
      assert_equal 'AMD EPYC 7763 64-Core Processor', facts['cpu_model']
      assert_equal 63, facts['memory_total_gb']
      assert_equal 10, facts['memory_free_gb_at_start']
      assert_in_delta 3.5, facts['load_at_start']
    end
  end

  def test_each_unreadable_field_is_unknown_without_failing
    with_proc(cpuinfo: "processor\t: 0\nFeatures\t: fp asimd\n", meminfo: "MemTotal: lots\n") do |reader|
      facts = Facts.start(environment: {}, reader:)
      assert_equal %w[UNKNOWN UNKNOWN UNKNOWN UNKNOWN],
                   facts.values_at('cpu_model', 'memory_total_gb', 'memory_free_gb_at_start', 'load_at_start')
    end
    failing = Facts::Reader.new(platform: 'darwin23', command: ->(*) { raise Errno::ENOENT })
    assert_equal 'UNKNOWN', Facts.start(environment: {}, reader: failing)['cpu_model']
    assert_equal 'UNKNOWN', Facts.start(environment: {}, reader: Facts::Reader.new(platform: 'mingw'))['load_at_start']
  end

  def test_measure_returns_the_block_value_and_reads_load_after_it
    loads = ['{ 1.0 1.0 1.0 }', '{ 9.0 1.0 1.0 }']
    reader = Facts::Reader.new(platform: 'darwin23',
                               command: ->(*arguments) { arguments.last == 'vm.loadavg' ? loads.shift : nil })
    value, recorded = Facts.measure(environment: {}, reader:) { [:ran, { 'duration_ms' => 5 }] }
    assert_equal :ran, value
    assert_equal 5, recorded.fetch('duration_ms')
    assert_equal [1.0, 9.0], recorded.fetch('machine').values_at('load_at_start', 'load_at_end')
    assert_equal Facts::FIELDS.sort, recorded.fetch('machine').keys.sort
  end

  def test_free_text_and_host_names_never_enter_the_facts
    odd = Facts::Reader.new(platform: 'darwin23', command: ->(*) { "Model /Users/someone\n" })
    assert_equal 'UNKNOWN', Facts.start(environment: {}, reader: odd)['cpu_model']
    host = Shaka::Doctor::MachineAlias.system_name
    environment = { 'SHAKA_MACHINE_ALIAS' => host.to_s.split('.').first }
    assert_equal 'UNKNOWN', Facts.start(environment:, reader: odd)['alias']
  end

  def test_only_a_safe_alias_that_is_not_the_host_name_publishes
    assert_equal 'm5', Shaka::Doctor::MachineAlias.publishable({ 'SHAKA_MACHINE_ALIAS' => 'm5' }, host_name: 'lab')
    assert_nil Shaka::Doctor::MachineAlias.publishable({ 'SHAKA_MACHINE_ALIAS' => 'lab' }, host_name: 'lab.local')
    assert_nil Shaka::Doctor::MachineAlias.publishable({ 'SHAKA_MACHINE_ALIAS' => 'two words' }, host_name: 'lab')
  end

  def test_evidence_run_records_the_machine_beside_its_duration
    with_checkout do |root, ref|
      machine = run_check(root, ref).fetch('machine')
      assert_equal Facts::FIELDS.sort, machine.keys.sort
      refute_includes JSON.generate(machine), root
    end
  end

  def test_summary_reads_duration_alias_and_facts
    machine = { 'alias' => 'm5', 'cpu_model' => 'Apple M5 Max', 'cpu_cores' => 18, 'memory_total_gb' => 128,
                'memory_free_gb_at_start' => 3, 'load_at_start' => 140.4, 'load_at_end' => 450.0 }
    assert_equal '27m on m5 (Apple M5 Max, 18 cores, 128 GB RAM, 3 GB free, load 140→450)',
                 summary(1_620_000, machine)
    assert_equal '7m 30s (load 2.5)', summary(450_000, { 'load_at_start' => 2.5, 'load_at_end' => 2.5 })
  end

  def test_summary_drops_unknown_and_malformed_facts_and_needs_a_duration
    edited = { 'alias' => 'my laptop', 'cpu_model' => 'x|y', 'cpu_cores' => '10', 'load_at_start' => 'UNKNOWN' }
    assert_equal '45s', summary(45_000, edited)
    assert_equal '1h 5m', summary(3_900_000, nil)
    assert_nil Shaka::RunSummary.render({ 'machine' => edited })
  end

  def test_settings_block_shows_the_run_beside_validation
    settings = snapshot(command: 'validate')
    verdict = { 'checks' => { 'validation' => [{ 'original' => { 'public_settings' => settings,
                                                                 'duration_ms' => 1_620_000,
                                                                 'machine' => { 'cpu_cores' => 10 } } }],
                              'review' => [] } }
    body = Shaka::PublicationSettings.new(verdict:, current: settings).detail.fetch('body')
    assert_includes body, '| validate: 27m (10 cores) |'
  end

  private

  def summary(duration_ms, machine) = Shaka::RunSummary.render({ 'duration_ms' => duration_ms, 'machine' => machine })

  def with_proc(**files)
    Dir.mktmpdir do |directory|
      files.each { |name, text| File.write(File.join(directory, name.to_s), text) }
      yield Facts::Reader.new(platform: 'linux-gnu', proc_root: directory)
    end
  end
end
