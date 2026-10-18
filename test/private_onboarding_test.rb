# frozen_string_literal: true

require_relative 'private_setup_test'

class PrivateOnboardingTest < Minitest::Test
  include PrivateSetupFixture

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def cli(root, *) = Open3.capture3(COMMAND, *, '--root', root)

  def test_private_check_reports_commands_without_granting_policy
    with_setup do |root, ref|
      setup_private(root, ref)
      output, error, status = cli(root, 'seam', 'private', 'check', '--ref', ref)
      assert_predicate status, :success?, error
      result = JSON.parse(output)
      assert_local_report(result, ref)
      _, _, trusted_status = cli(root, 'seam', 'check', '--ref', ref)
      refute_predicate trusted_status, :success?
    end
  end

  def assert_local_report(result, ref)
    assert_equal '.agents/shaka/bin/test', result.dig('commands', 'test')
    assert_equal 'ask', result.dig('merge', 'preference')
    refute result.fetch('merge').key?('required_checks')
    assert_equal({ 'mode' => 'private/local', 'grants_policy' => false, 'grants_merge_authority' => false,
                   'ref' => ref, 'trusted_source' => 'absent' }, result.fetch('validation'))
  end

  def test_private_check_requires_an_immutable_ref
    with_setup do |root, ref|
      setup_private(root, ref)
      [[], ['--ref', 'HEAD']].each do |flags|
        _, error, status = cli(root, 'seam', 'private', 'check', *flags)
        refute_predicate status, :success?
        assert_match(/--ref is required|immutable commit SHA/, error)
      end
    end
  end

  def test_private_check_rejects_partial_settings_and_preserves_recovery
    with_setup do |root, ref|
      result = setup_private(root, ref)
      copy = File.binread(copy_path(result))
      File.delete(File.join(root, '.agents/shaka/bin/validate'))
      _, error, status = cli(root, 'seam', 'private', 'check', '--ref', ref)
      refute_predicate status, :success?
      assert_includes error, 'partial'
      assert_includes error, 'validate'
      assert_equal copy, File.binread(copy_path(result))
    end
  end

  def test_private_check_refuses_staged_team_adoption
    with_setup do |root, ref|
      result = setup_private(root, ref)
      copy = File.binread(copy_path(result))
      git(root, 'add', '-f', '.agents/shaka/config.yml')
      _, error, status = cli(root, 'seam', 'private', 'check', '--ref', ref)
      refute_predicate status, :success?
      assert_includes error, 'conflicting'
      assert_equal copy, File.binread(copy_path(result))
    end
  end

  def test_prefix_works_before_setup_and_then_uses_individual_settings
    with_setup do |root, ref|
      assert_fallback_prefix(root, ref)
      setup_private(root, ref)
      File.write(config_path(root), "#{File.read(config_path(root))}repo_prefix: LOCAL\n")
      output, error, status = cli(root, 'prefix', '--ref', ref)
      assert_predicate status, :success?, error
      assert_equal({ 'prefix' => 'LOCAL', 'source' => 'individual' }, JSON.parse(output))
    end
  end

  def assert_fallback_prefix(root, ref)
    output, error, status = cli(root, 'prefix', '--ref', ref)
    assert_predicate status, :success?, error
    assert_equal 'fallback', JSON.parse(output).fetch('source')
  end

  def test_clones_and_linked_worktrees_continue_with_only_a_feature_diff
    with_setup do |root, ref|
      Dir.mktmpdir('shaka-private-onboarding') do |parent|
        clone = File.join(parent, 'clone')
        linked = File.join(parent, 'linked')
        git(root, 'clone', '--quiet', root, clone)
        git(root, 'worktree', 'add', '--quiet', '--detach', linked, ref)
        [clone, linked].each { |checkout| assert_feature_validation(checkout, ref) }
      end
    end
  end

  def assert_feature_validation(root, ref)
    setup_private(root, ref)
    _, error, status = cli(root, 'seam', 'private', 'check', '--ref', ref)
    assert_predicate status, :success?, error
    File.write(File.join(root, 'README.md'), "feature fixed\n")
    git(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-am', 'feature', '--quiet')
    diff = Open3.capture2('git', '-C', root, 'diff', '--name-only', ref, 'HEAD').first
    assert_equal "README.md\n", diff
    assert_evidence_commands(root, ref)
  end

  def assert_evidence_commands(root, ref)
    _, error, status = cli(root, 'evidence', 'run', '--ref', ref, '--repository', 'owner/repo', '--command', 'validate')
    assert_predicate status, :success?, error
    _, error, status = cli(root, 'evidence', 'guard', '--ref', ref, '--repository', 'owner/repo',
                           '--base', ref, '--head', head(root))
    assert_predicate status, :success?, error
  end
end
