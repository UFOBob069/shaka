# frozen_string_literal: true

require_relative 'official_install_support'

# Runs an installer refusal and then the command it names, exactly as printed.
module InstallRefusalSupport
  include OfficialInstallSupport

  private

  def checkout = File.realpath(@root)

  def refusal(action, *expected)
    output, status = invoke(action)
    refute_predicate status, :success?, output
    expected.each { |text| assert_includes output, text }
    assert_match(/Next: \S/, output)
    output
  end

  def assert_succeeds(action)
    output, status = invoke(action)
    assert_predicate status, :success?, output
  end

  def run_next(output)
    line = output.lines.find { |text| text.include?('Next: ') }.chomp
    command = line[/, run (.+)\z/, 1] || line[/Next: (.+)\z/, 1]
    path = "#{File.dirname(RbConfig.ruby)}:#{ENV.fetch('PATH')}"
    result = Open3.capture2e({ 'HOME' => @home, 'PATH' => path }, command.strip)
    assert_predicate result.last, :success?, result.first
    result
  end
end
