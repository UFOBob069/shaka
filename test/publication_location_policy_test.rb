# frozen_string_literal: true

require_relative 'evidence_fixture'
require 'shaka/publication/settings'
require 'shaka/publication/wip_details'

class PublicationLocationPolicyTest < Minitest::Test
  include EvidenceFixture

  LOCATOR = 'codex://threads/0199a213-81c0-7800-8aa1-bbab2a035a53'
  RECOVERY = Shaka::WipDetails::FIELDS.keys.to_h { |key| [key, 'UNKNOWN'] }.merge(
    'owner' => 'laptop · Codex · t1', 'revision' => 'a' * 40, 'state' => 'paused',
    'next_action' => 'Resume the owning chat'
  ).freeze

  def test_hiding_the_checkout_path_keeps_what_recovery_needs
    settings = Shaka::PublicationSettings.new(current: { 'wip.include_checkout_path' => false })
    body = location_body(settings)
    assert_includes body, '| Workspace | REDACTED |'
    assert_checkout_path_withheld(body)
    assert_recovery_fields_kept(body)
  end

  def test_allowed_policy_preserves_locations_and_host_unknowns
    settings = Shaka::PublicationSettings.new(current: { 'wip.include_checkout_path' => true })
    assert_includes location_body(settings), '| Workspace | /private/customer/project |'
    assert_includes location_body(settings, thread: 'UNKNOWN'), '| Chat link | UNKNOWN |'
  end

  def test_missing_ref_has_a_distinct_safe_recovery_diagnostic
    with_checkout do |root, ref|
      body = location_body(prepare(root, nil, {}, head: ref))
      assert_includes body, 'settings not read'
      assert_includes body, 'rerun description with --ref'
      assert_checkout_path_withheld(body)
      assert_recovery_fields_kept(body)
    end
  end

  def test_failed_settings_load_remains_publishable_without_evidence_and_withholds_locations
    with_checkout do |root, ref|
      body = location_body(prepare(root, 'missing-policy-ref', {}, head: ref))
      assert_includes body, 'settings unavailable'
      assert_includes body, 'fix seam check --ref'
      assert_checkout_path_withheld(body)
      assert_recovery_fields_kept(body)
      refute_includes body, 'missing-policy-ref'
    end
  end

  def test_a_committed_earlier_setting_name_still_hides_the_checkout_path
    with_checkout do |root, _ref|
      path = Dir[File.join(root, '.agents/{agent-workflow.yml,shaka/config.yml}')].first
      File.write(path, YAML.dump(YAML.safe_load_file(path).merge('wip' => { 'include_locations' => false })))
      git(root, 'add', '-A')
      commit(root)
      body = location_body(prepare(root, git(root, 'rev-parse', 'HEAD'), {}))
      assert_includes body, '| Workspace | REDACTED |'
      assert_recovery_fields_kept(body)
    end
  end

  def test_the_earlier_setting_name_no_longer_reaches_publication
    settings = Shaka::PublicationSettings.new(current: { 'wip.include_locations' => true })
    assert_checkout_path_withheld(location_body(settings))
  end

  def test_missing_location_field_cannot_authorize_publication
    settings = Shaka::PublicationSettings.new(current: {})
    assert_checkout_path_withheld(location_body(settings))
    refute_predicate settings, :include_checkout_path?
  end

  def test_required_settings_load_still_refuses_failure
    with_checkout do |root, _ref|
      assert_raises(Shaka::Error) do
        Shaka::PublicationSettings.current_settings(root:, ref: 'missing-policy-ref',
                                                    repository: 'shakacode/shaka', required: true)
      end
    end
  end

  private

  def location_body(settings, thread: LOCATOR)
    wip = RECOVERY.merge('workspace' => '/private/customer/project', 'thread' => thread)
    Shaka::WipDetails.new(wip, path_redaction: settings.path_redaction).detail.fetch('body')
  end

  def assert_checkout_path_withheld(body)
    refute_includes body, '/private/customer/project'
  end

  def assert_recovery_fields_kept(body)
    assert_includes body, "| Chat link | #{LOCATOR} |"
    assert_includes body, '| Owner | laptop · Codex · t1 |'
    assert_includes body, "| Revision | #{'a' * 40} |"
    assert_includes body, '| State | paused |'
    assert_includes body, '| Next action | Resume the owning chat |'
  end

  def prepare(root, ref, options, head: ref)
    pull = { 'changed_files' => 0, 'head' => { 'sha' => head }, 'base' => { 'sha' => ref } }
    Shaka::PublicationSettings.prepare(root:, ref:, pull:,
                                       options: options.merge(root:), github: empty_diff)
  end

  def empty_diff
    Object.new.tap do |github|
      def github.repository = 'shakacode/shaka'
      def github.number = 1
      def github.api_list(_path) = []
    end
  end
end
