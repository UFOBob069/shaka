# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/install/directory_safety'

class InstallDirectorySafetyReasonTest < Minitest::Test
  include Shaka::Install::DirectorySafety

  Entry = Struct.new(:uid, :mode, :directory) do
    def directory? = directory
  end

  OTHER_UID = Process.euid + 4242
  UNMAPPED = "         0       1000          1\n"
  FULL_MAP = "         0          0 4294967295\n"

  def test_safe_directory_has_no_reason
    assert_nil unsafe_reason(Entry.new(Process.euid, 0o755, true), nil)
    assert_nil unsafe_reason(Entry.new(0, 0o755, true), Entry.new(Process.euid, 0o755, true))
  end

  def test_another_owner_is_named_with_both_accounts
    reason = unsafe_reason(Entry.new(OTHER_UID, 0o755, true), nil)

    assert_includes reason, "owned by uid #{OTHER_UID}"
    assert_includes reason, "uid #{Process.euid}"
    refute_includes reason, 'sandbox'
  end

  def test_owner_hidden_by_a_sandbox_says_to_install_outside_it
    assert hidden_owner?(65_534, overflow: "65534\n", uid_map: UNMAPPED)
    reason = owner_reason(65_534, hidden: true)

    assert_includes reason, 'owned by uid 65534'
    assert_includes reason, 'sandbox'
    assert_includes reason, 'outside'
  end

  def test_a_real_nobody_account_is_not_reported_as_hidden
    refute hidden_owner?(65_534, overflow: "65534\n", uid_map: FULL_MAP)
    refute hidden_owner?(1001, overflow: "65534\n", uid_map: UNMAPPED)
    refute hidden_owner?(65_534, overflow: nil, uid_map: nil)
  end

  def test_other_failures_name_their_rule
    assert_includes unsafe_reason(Entry.new(Process.euid, 0o644, false), nil), 'not a directory'
    assert_includes unsafe_reason(Entry.new(Process.euid, 0o775, true), nil), 'group or world writable'
  end

  def test_installer_error_explains_a_writable_directory
    Dir.mktmpdir do |directory|
      File.chmod(0o777, directory)
      error = assert_raises(ArgumentError) { verify_safe_directory(directory, 'Managed directory') }

      assert_includes error.message, 'Managed directory is unsafe'
      assert_includes error.message, 'group or world writable'
    end
  end
end
