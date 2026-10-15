# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'rbconfig'

class RunTestsTest < Minitest::Test
  RUNNER = File.expand_path('../bin/run-tests', __dir__)

  def setup
    @directory = Dir.mktmpdir('run-tests')
    @marker = File.join(@directory, 'ran.txt')
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_every_test_runs_exactly_once_across_workers
    files = %w[alpha beta gamma].map { |name| fixture(name, %w[one two]) }
    output, status = run_tests(files, workers: 2)

    assert_predicate status, :success?, output
    expected = %w[alpha beta gamma].product(%w[one two]).map { |pair| pair.join('#') }
    assert_equal expected, File.readlines(@marker, chomp: true).sort
    assert_includes output, 'Total: 6 runs'
  end

  def test_a_failure_in_any_worker_fails_the_run
    files = [fixture('alpha', %w[one]), fixture('beta', %w[one], failing: true)]
    output, status = run_tests(files, workers: 2)

    refute_predicate status, :success?
    assert_includes output, 'beta one failed'
  end

  def test_a_worker_that_cannot_load_its_files_fails_the_run
    broken = File.join(@directory, 'broken_test.rb')
    File.write(broken, "raise 'cannot load'\n")
    output, status = run_tests([fixture('alpha', %w[one]), broken], workers: 2)

    refute_predicate status, :success?
    assert_includes output, 'cannot load'
  end

  private

  def fixture(name, tests, failing: false)
    path = File.join(@directory, "#{name}_test.rb")
    methods = tests.map { |test| fixture_method(name, test, failing) }
    File.write(path, "require 'minitest/autorun'\n\nclass #{name.capitalize}FixtureTest < Minitest::Test\n" \
                     "#{methods.join}end\n")
    path
  end

  def fixture_method(name, test, failing)
    <<~RUBY
      def test_#{test}
        File.write(ENV.fetch('MARKER'), "#{name}##{test}\\n", mode: 'a')
        flunk '#{name} #{test} failed' if #{failing}
      end
    RUBY
  end

  def run_tests(files, workers:)
    env = { 'MARKER' => @marker, 'SHAKA_TEST_WORKERS' => workers.to_s }
    Open3.capture2e(env, RbConfig.ruby, RUNNER, *files)
  end
end
