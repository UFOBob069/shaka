# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'doctor_helper'

# Doctor names the install state and the one next step `install --status` chose.
class DoctorInstallStateTest < Minitest::Test
  include DoctorHelper

  def test_a_healthy_install_names_its_state
    report, = doctor
    assert_includes report, '[HEALTHY] Install state — A1 Default install, one host at /home/.agents/shaka'
  end

  def test_an_orphan_record_names_the_next_command
    orphan = lambda do
      { 'state' => 'C1', 'title' => 'Orphan installation record', 'severity' => 'attention',
        'location' => '/home/.agents/shaka', 'detail' => 'this record owns nothing',
        'next_command' => 'mv record record.retired' }
    end
    report, blocked = doctor(installation_status: orphan)
    assert_includes report, '[DEGRADED] Install state — C1 Orphan installation record'
    assert_includes report, 'Next: Run mv record record.retired.'
    refute blocked
  end

  def test_a_status_failure_is_reported_not_raised
    report, = doctor(installation_status: -> { raise ArgumentError, 'Installation Git operation failed' })
    assert_includes report, 'install --status could not run: Installation Git operation failed'
  end
end
