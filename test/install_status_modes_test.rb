# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'shaka/install/status_checkout'

# A file owned by another account cannot be fixed with chmod, so status asks a person instead.
class InstallStatusModesTest < Minitest::Test
  def test_a_file_owned_by_another_account_gets_a_decision
    Dir.mktmpdir do |root|
      skills = write_skill(root)
      checkout = Shaka::Install::StatusCheckout.new(root, 'targets' => [{ 'names' => ['shaka'] }])
      checkout.define_singleton_method(:owned?) { |path| path != skills }
      finding = checkout.send(:unsafe_files)
      assert_equal ['B10', nil], finding.values_at('id', 'next_command')
      assert_includes finding['decision'], 'owner'
    end
  end

  private

  # A skill the installer accepts: its entry points exist and the helper is executable.
  def write_skill(root)
    skills = File.join(root, 'skills')
    helper = File.join(skills, 'shaka/scripts/shaka')
    FileUtils.mkdir_p(File.dirname(helper))
    File.write(File.join(skills, 'shaka/SKILL.md'), 'skill')
    File.write(helper, "#!/bin/sh\n")
    File.chmod(0o755, helper)
    skills
  end
end
