# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'rbconfig'
require_relative '../eval/lib/shaka/evaluation/native_usage'
require_relative 'support/evaluation_native_fixture'

class EvaluationNativeSourceTest < Minitest::Test
  include EvaluationNativeFixture

  def setup
    @directory = Dir.mktmpdir
    setup_native_reader
  end

  def teardown = FileUtils.remove_entry(@directory)

  def test_rate_card_is_pinned_at_construction
    path = File.join(@directory, Shaka::Evaluation::NativeUsage::CARD)
    FileUtils.mkdir_p(File.dirname(path))
    source = File.binread(File.join(@root, Shaka::Evaluation::NativeUsage::CARD))
    File.binwrite(path, source)
    @reader = Shaka::Evaluation::NativeUsage.new(helper: @helper, rate_root: @directory)
    File.binwrite(path, 'invalid replacement')
    assert_in_delta 0.21, capture('codex', codex_rows)['cache_neutral_dollars'], 0.000001
    assert_equal "sha256:#{Digest::SHA256.hexdigest(source)}", @reader.rate_card_hash
  end

  def test_private_snapshots_are_removed_and_sources_unchanged
    @reader = Shaka::Evaluation::NativeUsage.new(helper: recording_helper, rate_root: @root)
    capture('codex', codex_rows)
    observations = observations()
    assert_equal [[0o700, [0o600]]], observations.map { |row| [row['mode'], row['files'].uniq] }.uniq
    refute(observations.any? { |row| File.exist?(row['directory']) })
  end

  def test_source_counters_remain_unchanged
    capture('codex', codex_rows)
    assert_equal(codex_rows, File.readlines(File.join(@directory, 'session.jsonl')).map { |line| JSON.parse(line) })
  end

  def test_reader_failure_is_unknown_without_private_error_text
    path = File.join(@directory, 'helper')
    File.write(path, "#!#{RbConfig.ruby}\nwarn 'PRIVATE_FAILURE'; puts '{bad'; exit 1\n", perm: 0o700)
    @reader = Shaka::Evaluation::NativeUsage.new(helper: path, rate_root: @root)
    result = capture('codex', codex_rows)
    assert_equal 'UNKNOWN', result['cache_neutral_dollars']
    refute_includes JSON.generate(result), 'PRIVATE_FAILURE'
  end

  def test_unknown_billing_speed_is_not_silently_standard
    rows = claude_rows
    rows.last['message']['usage'].delete('speed')
    assert_equal 'UNKNOWN', capture('claude-code', rows)['cache_neutral_dollars']
  end

  def test_invalid_source_selection_reports_a_caller_error
    assert_raises(ArgumentError) { @reader.read(host: 'typo', files: ['unused']) }
    assert_raises(ArgumentError) { @reader.read(host: 'codex', files: nil) }
    assert_raises(ArgumentError) { @reader.read(host: 'codex', files: []) }
  end

  private

  def observations
    File.readlines(File.join(@directory, 'observed.jsonl')).map { |line| JSON.parse(line) }
  end

  def recording_helper
    write_helper(<<~RUBY)
      require 'json'
      directory = ARGV[ARGV.index('--rate-root') + 1]
      files = Dir.glob(File.join(directory, '**/*')).select { |file| File.file?(file) }
      record = {directory: directory, mode: File.stat(directory).mode & 0777,
                files: files.map { |file| File.stat(file).mode & 0777 }}
      File.open(#{File.join(@directory, 'observed.jsonl').inspect}, 'a') { |log| log.puts JSON.generate(record) }
      exec #{RbConfig.ruby.inspect}, #{@helper.inspect}, *ARGV
    RUBY
  end

  def write_helper(source)
    path = File.join(@directory, 'helper')
    File.write(path, "#!#{RbConfig.ruby}\n#{source}", perm: 0o700)
    path
  end
end
