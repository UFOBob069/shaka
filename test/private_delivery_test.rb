# frozen_string_literal: true

require_relative 'private_delivery_helper'

class PrivateDeliveryTest < Minitest::Test
  include PrivateDeliveryFixture

  def test_private_delivery_and_fresh_process_resumption
    with_trial do
      assert_reviewer('anthropic/claude')
      published = publish_delivery
      assert_equal @ref, published['commit_id']
      resumed = invoke('handoff')
      assert_empty resumed['owed']
      assert_equal @ref, resumed['head']
      assert_includes File.read(File.join(@state, 'pull.json')), 'private/local'
    end
  end

  def test_private_changes_supersede_evidence_and_change_reviewer_selection
    with_trial do
      validation, review = evidence_files
      select_private_grok
      assert_reviewer('xai/grok')
      publish_description(validation, review, exit_code: 1, error: 'missing or stale')
      publish_delivery
      assert_empty invoke('handoff')['owed']
      assert_reviewer_arguments(['-m', 'grok-4.7'], ['--reasoning-effort', 'high'])
    end
  end

  def test_new_head_cannot_reuse_old_walkthrough_or_wip
    with_trial do
      publish_delivery
      alter_pull { |pull| pull['snapshot']['headRefOid'] = 'd' * 40 }
      resumed = invoke('handoff', exit_code: 2)
      assert_stale_handoff(resumed)
      invoke('walkthrough', '--head', @ref, '--content-file', walkthrough_file,
             exit_code: 1, error: 'expected head')
    end
  end

  private

  def select_private_grok
    update_private do |data|
      data['review']['local_review_agents'] = [{ 'provider' => 'xai', 'model_family' => 'grok',
                                                 'model' => 'grok-4.7', 'effort' => 'high' }]
    end
  end
end

class PrivateDeliveryBoundaryTest < Minitest::Test
  include PrivateDeliveryFixture

  def test_absent_and_fork_tracked_configuration_cannot_become_private_settings
    with_trial do
      directory = File.join(@root, '.agents/shaka')
      FileUtils.rm_rf(directory)
      %w[reviewer walkthrough handoff].each do |command|
        args = command == 'reviewer' ? ['--implementer', 'openai/codex'] : []
        invoke(command, *args, exit_code: 1, error: 'Cannot read')
      end
    end
  end

  def test_fork_tracked_configuration_cannot_become_private_settings
    with_trial do
      git(@root, 'add', '-f', '.agents/shaka')
      commit(@root)
      invoke('reviewer', '--implementer', 'openai/codex', exit_code: 1, error: 'Cannot read')
      invoke('handoff', exit_code: 1, error: 'Cannot read')
    end
  end

  def test_private_required_checks_are_not_a_native_gate_fallback
    with_trial do
      update_private { |data| data['merge']['required_checks'] = ['private-check'] }
      assert_empty invoke('pr')['requiredChecks']
      publish_delivery
      assert_empty invoke('handoff')['owed']
    end
  end

  def test_private_auto_is_not_merge_authority_and_native_gates_remain_live
    with_trial do
      update_private { |data| data['merge'] = { 'preference' => 'auto', 'required_checks' => ['private-check'] } }
      alter_pull do |pull|
        pull['native_checks'] = [{ 'name' => 'live-gate', 'state' => 'PENDING', 'bucket' => 'pending' }]
      end
      assert_native_gate
      invoke('merge', '--head', @ref, '--base', 'main', '--walkthrough', '7',
             exit_code: 1, error: 'Cannot read')
      assert_includes invoke('handoff', exit_code: 2)['status'], '1 pending'
    end
  end
end
