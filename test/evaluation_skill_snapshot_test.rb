# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/skill_snapshot'

class EvaluationSkillSnapshotTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @root = File.join(@directory, 'skills/shaka')
    FileUtils.mkdir_p(File.join(@root, 'references'))
    File.write(File.join(@root, 'SKILL.md'), 'read references/guide.md')
    File.write(File.join(@root, 'references/guide.md'), 'run helper')
    git('init', '-q')
    git('add', '.')
    git('-c', 'user.name=Synthetic', '-c', 'user.email=synthetic@example.invalid', 'commit', '-qm', 'fixture')
  end

  def teardown = FileUtils.remove_entry(@directory)
  def read = Shaka::Evaluation::SkillSnapshot.read(@root)

  def test_package_includes_guides_and_modified_state
    before = read
    refute before['skill_modified']
    assert_match(/\A[0-9a-f]{40}\z/, before['skill_commit'])
    File.write(File.join(@root, 'references/guide.md'), 'different helper')
    after = read
    refute_equal before['skill_package_digest'], after['skill_package_digest']
    assert after['skill_modified']
  end

  def test_package_includes_hidden_files
    before = read
    File.write(File.join(@root, '.hidden'), 'loaded helper')
    refute_equal before['skill_package_digest'], read['skill_package_digest']
  end

  def test_executable_mode_affects_package_even_when_harbor_content_hash_matches
    before = read
    File.chmod(0o755, File.join(@root, 'references/guide.md'))
    assert_equal before['harbor_digest'], read['harbor_digest']
    refute_equal before['skill_package_digest'], read['skill_package_digest']
  end

  def test_harbor_digest_uses_path_component_order_for_directory_and_file_prefixes
    FileUtils.mkdir_p(File.join(@root, 'references/guide'))
    File.write(File.join(@root, 'references/guide/helper'), 'nested')
    expected = 'sha256:cb7ee882b4adddb6d9c5b68c6a4ab14b35262d18f538e4acb7521c0de54ce802'
    assert_equal expected, read['harbor_digest']
  end

  def test_read_permissions_affect_package_identity
    before = read
    File.chmod(0o600, File.join(@root, 'references/guide.md'))
    refute_equal before['skill_package_digest'], read['skill_package_digest']
  end

  def test_directory_traversal_permissions_affect_package_identity
    before = read
    File.chmod(0o700, File.join(@root, 'references'))
    refute_equal before['skill_package_digest'], read['skill_package_digest']
  end

  def test_symlink_to_external_helper_never_claims_complete_capture
    File.symlink(File.join(@root, 'SKILL.md'), File.join(@root, 'references/link'))
    assert_empty read
  end

  def test_missing_checkout_keeps_content_but_marks_git_identity_unknown
    FileUtils.rm_rf(File.join(@directory, '.git'))
    assert_equal 'UNKNOWN', read['skill_commit']
    assert_equal 'UNKNOWN', read['skill_modified']
    assert_match(/\Asha256:[a-f0-9]{64}\z/, read['skill_package_digest'])
  end

  private

  def git(*)
    _, error, status = Open3.capture3(TEST_GIT, '-C', @directory, *)
    raise error unless status.success?
  end
end
