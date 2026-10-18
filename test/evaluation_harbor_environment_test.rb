# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/harbor_environment'
require_relative 'support/evaluation_harbor_environment_fixture'

class EvaluationHarborEnvironmentTest < Minitest::Test
  include EvaluationHarborEnvironmentFixture

  def capture(rows = container_readbacks, name: 'shaka-synthetic')
    Shaka::Evaluation::HarborEnvironment.capture(rows, name: name)
  end

  def test_digest_keeps_roles_and_controls_without_host_identity_or_secrets
    observed = capture
    assert_match(/\Asha256:[a-f0-9]{64}\z/, observed['digest'])
    rows = observed.dig('manifest', 'containers')
    assert_equal 4, rows.length
    assert_equal 2_147_483_648, rows.first.dig('controls', 'Memory')
    %w[private-id synthetic-secret /private/controller shaka-synthetic].each do |private_value|
      refute_includes JSON.generate(observed), private_value
    end
  end

  def test_reservation_ids_host_sources_and_inspection_order_do_not_change_identity
    other = container_readbacks('shaka-other').reverse
    other.each { different_private_metadata(it) }
    assert_equal capture['digest'], capture(other, name: 'shaka-other')['digest']
  end

  def test_verifier_sidecar_image_changes_change_identity
    rows = container_readbacks
    rows.last['Image'] = "sha256:#{'b' * 64}"
    refute_equal capture['digest'], capture(rows)['digest']
  end

  def test_icmp_control_changes_change_identity
    rows = container_readbacks
    rows.last['HostConfig']['Sysctls']['net.ipv4.ping_group_range'] = '0 2147483647'
    refute_equal capture['digest'], capture(rows)['digest']
  end

  def test_skill_mount_write_access_changes_change_identity
    rows = container_readbacks
    rows.first['Mounts'].first['RW'] = true
    refute_equal capture['digest'], capture(rows)['digest']
  end

  def test_missing_verifier_stays_unknown
    assert_equal 'UNKNOWN', capture([])['digest']
    assert_equal 'UNKNOWN', capture(container_readbacks.take(2))['digest']
  end

  def test_incomplete_inspection_stays_unknown
    rows = container_readbacks
    rows.last['HostConfig'].delete('Memory')
    assert_equal 'UNKNOWN', capture(rows)['digest']
  end

  def test_missing_service_label_stays_unknown
    rows = container_readbacks
    rows.last['Config']['Labels'].delete('com.docker.compose.service')
    assert_equal 'UNKNOWN', capture(rows)['digest']
  end

  def test_unreadable_limits_are_not_hashed_as_known_values
    rows = container_readbacks
    rows.last['HostConfig']['Memory'] = nil
    assert_equal 'UNKNOWN', capture(rows)['digest']
  end

  def test_duplicate_services_and_foreign_ownership_are_not_complete_readbacks
    rows = container_readbacks
    assert_equal 'UNKNOWN', capture(rows + [rows.last])['digest']
    rows.last['Config']['Labels']['com.docker.compose.project'] = 'shaka-other__verifier__trial'
    assert_equal 'UNKNOWN', capture(rows)['digest']
  end

  def test_services_split_across_verifier_projects_stay_unknown
    rows = container_readbacks
    rows.last['Config']['Labels']['com.docker.compose.project'] = 'shaka-synthetic__verifier__other'
    assert_equal 'UNKNOWN', capture(rows)['digest']
  end

  private

  def different_private_metadata(row)
    row['Id'] = 'different-private-id'
    row['Mounts'].first['Source'] = '/another/private/location'
    row['HostConfig'] = row['HostConfig'].to_a.reverse.to_h
  end
end
