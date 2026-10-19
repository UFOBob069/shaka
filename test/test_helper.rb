# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'open3'
require 'fileutils'

# Helper calls the tests spawn stay out of the developer's own call log.
ENV['SHAKA_CALL_LOG'] = 'off'
# This checkout is not the developer's linked installation, so every spawned call would say so.
ENV['SHAKA_NOTICES'] = 'off'
# Background maintenance outlives a fixture repository and races Dir.mktmpdir's cleanup.
# Trial preparation refuses an inherited GIT_CONFIG_PARAMETERS, so a generated global config
# carries the setting after including the files Git would have read, in Git's own order.
module TestGitConfig
  module_function

  # Git expands ~ when it reads the include, so a test that changes HOME still gets that home's files.
  def own_files(env)
    return [env['GIT_CONFIG_GLOBAL']] if env['GIT_CONFIG_GLOBAL']

    xdg = env['XDG_CONFIG_HOME'] ? File.join(env['XDG_CONFIG_HOME'], 'git/config') : '~/.config/git/config'
    [xdg, '~/.gitconfig']
  end

  # Unquoted, Git would end the path at # or ;.
  def quoted(path) = %("#{path.gsub(/[\\"]/) { "\\#{it}" }}")

  def text(env)
    includes = own_files(env).map { |file| "[include]\n\tpath = #{quoted(file)}\n" }.join
    "#{includes}[maintenance]\n\tauto = false\n[gc]\n\tauto = 0\n"
  end
end

TEST_GIT_CONFIG_DIR = Dir.mktmpdir('shaka-test-gitconfig')
Minitest.after_run { FileUtils.remove_entry(TEST_GIT_CONFIG_DIR, true) }
ENV['GIT_CONFIG_GLOBAL'] = File.join(TEST_GIT_CONFIG_DIR, 'config').tap do |path|
  File.write(path, TestGitConfig.text(ENV))
end

TEST_GIT = ENV.fetch('PATH').split(File::PATH_SEPARATOR).map { |dir| File.join(dir, 'git') }.find do |path|
  File.file?(path) && File.executable?(path)
end or raise 'git executable not found'

$LOAD_PATH.unshift File.expand_path('../skills/shaka/lib', __dir__)
require 'shaka/usage/usage_records'

# The identity every usage record carries; tests add the columns they render.
USAGE_RECORD = { 'host' => 'claude-code', 'sources' => ['s1'], 'responses' => ['c1'],
                 'contribution' => 'implementation', 'commits' => ['a' * 40], 'complete' => true,
                 'from' => '2026-09-14T12:00:00Z', 'to' => '2026-09-14T13:00:00Z' }.freeze

# What every description states about its purpose and proof; tests replace a field to exercise it.
INTENT = { 'why' => 'Review comments showed rebased commits as plain text.',
           'scope' => 'Commit links in local review comments.',
           'leaves_out' => 'The closing attestation line.',
           'safe_because' => 'A copy must make the identical change.', 'review_effort' => 2 }.freeze
VERIFICATION = { 'checks' => ['Ran `bin/validate`: all tests passed.'],
                 'not_verified' => 'Nothing.' }.freeze

module MetricAssert
  def assert_metric(haystack, label, *values)
    row = "| #{label} | #{values.join(' | ')} |"
    assert_match(/(?:^|\n)#{Regexp.escape(row)}(?:\n|\z)/, haystack)
  end
end

# Descriptions accept only usage `shaka usage` marked, so fixtures wrap their tables the same way.
module RenderedUsage
  FIELDS = { 'host' => 'codex', 'sources' => ['s1'], 'responses' => ['r1'], 'contribution' => 'implementation',
             'commits' => ['a' * 40], 'complete' => true,
             'from' => '2026-09-14T12:00:00Z', 'to' => '2026-09-14T13:00:00Z' }.freeze

  module_function

  def body(table) = "#{Shaka::UsageRecords.begin_mark(FIELDS)}\n#{table}\n#{Shaka::UsageRecords::END_MARK}"
end

# Report identity digests are hexadecimal, so they can contain any refuted number by chance.
module UsageIdentityText
  def without_usage_identity(report) = report.sub(/\A<!-- shaka:usage .*\n/, '')
end

module BooleanAssert
  def assert_true(value, message = nil)
    assert_instance_of(TrueClass, value, message)
  end

  def assert_false(value, message = nil)
    assert_instance_of(FalseClass, value, message)
  end
end

module Minitest
  class Test
    include MetricAssert
    include UsageIdentityText
    include BooleanAssert
  end
end
