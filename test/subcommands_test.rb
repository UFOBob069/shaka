# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../skills/shaka/lib/shaka/subcommands'

class SubcommandsTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def test_usage_banner_lists_every_dispatched_command_and_operation
    output, error, status = Open3.capture3(COMMAND, '--help')
    assert_predicate status, :success?, error
    assert_includes output, 'shaka pr watch OWNER/REPO NUMBER'
    Shaka::Subcommands.usage_lines.each { |line| assert_match(/^ +#{Regexp.escape(line)}$/, output) }
  end

  def test_every_command_and_operation_prints_its_own_help
    Shaka::Subcommands::TABLE.each do |name, entry|
      invocations = entry.operations.empty? ? [[]] : entry.operations.zip
      invocations.each do |words|
        output, status = help(entry, words)
        label = ['shaka', name, *words, '--help'].join(' ')
        assert_equal 0, status, "#{label} failed"
        assert_includes output, "shaka #{name}", "#{label} names another program"
      end
    end
  end

  private

  # Some commands print help and exit; others return a status.
  def help(entry, words)
    status = nil
    output, = capture_io do
      status = entry.run.call([*words, '--help'])
    rescue SystemExit => e
      status = e.status
    end
    [output, status]
  end
end
