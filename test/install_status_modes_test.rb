# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'shaka/install/status_checkout'

# A file owned by another account cannot be fixed with chmod, so status asks a person instead.
class InstallStatusModesTest < Minitest::Test
  def test_a_file_owned_by_another_account_gets_a_decision
    Dir.mktmpdir do |root|
      skills = File.join(root, 'skills')
      Dir.mkdir(skills)
      checkout = Shaka::Install::StatusCheckout.new(root, 'targets' => [{ 'names' => ['shaka'] }])
      checkout.define_singleton_method(:owned?) { |path| path != skills }
      finding = checkout.send(:unsafe_files)
      assert_equal ['B10', nil], finding.values_at('id', 'next_command')
      assert_includes finding['decision'], 'owner'
    end
  end
end
