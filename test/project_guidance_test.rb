# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'project_guidance_helper'

class ProjectGuidanceTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include ProjectGuidanceHelper

  def test_absent_guidance_leaves_the_effective_contract_unchanged
    with_repository do |root|
      refute Shaka::RepositoryConfig.load(root:).to_h.key?('project_guidance')
    end
  end

  def test_effective_contract_lists_configured_guidance
    with_guidance(GUIDANCE) do |root|
      assert_equal GUIDANCE, Shaka::RepositoryConfig.load(root:).to_h.fetch('project_guidance')
    end
  end

  def test_rejects_invalid_guidance_settings
    [true, { 'other' => 'x.md' }, { 'pr_evidence' => '' }, { 'pr_evidence' => '../outside.md' }].each do |guidance|
      with_repository('project_guidance' => guidance) do |root|
        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
        assert_includes error.message, 'project_guidance'
      end
    end
  end

  def test_rejects_missing_empty_oversized_or_non_utf8_files
    { nil => 'does not exist', '' => 'is empty', 'x' * 100_001 => 'exceeds', "\xFF".b => 'UTF-8' }
      .each do |text, message|
      with_guidance('pr_evidence' => '.agents/pr-evidence.md') do |root|
        path = File.join(root, '.agents/pr-evidence.md')
        text.nil? ? File.delete(path) : File.binwrite(path, text)
        error = assert_raises(Shaka::Error) { Shaka::RepositoryConfig.load(root:) }
        assert_includes error.message, 'project_guidance.pr_evidence'
        assert_includes error.message, message
      end
    end
  end

  def test_prints_the_trusted_commit_version_not_the_candidate_edit
    with_guidance(GUIDANCE) do |root|
      sha = commit(root)
      File.write(File.join(root, '.agents/merge-readiness.md'), 'Candidate replacement.')
      assert_equal 'Trusted merge_readiness.', guidance('merge_readiness', root, sha)
    end
  end

  def test_refuses_guidance_only_the_candidate_branch_configures
    with_repository do |root|
      sha = commit(root)
      File.write(File.join(root, '.agents/agent-workflow.yml'), YAML.dump(seam('project_guidance' => GUIDANCE)))
      write_guidance(root, GUIDANCE)
      error = assert_raises(Shaka::Error) { guidance('pr_evidence', root, sha) }
      assert_equal 'project_guidance.pr_evidence is not configured', error.message
    end
  end

  def test_trusted_guidance_change_updates_the_files_fingerprint
    with_guidance(GUIDANCE) do |root|
      first = files_fingerprint(root, commit(root))
      File.write(File.join(root, '.agents/pr-evidence.md'), 'Changed.')
      assert_equal first, files_fingerprint(root, Open3.capture2('git', '-C', root, 'rev-parse', 'HEAD').first.strip)
      system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
             'commit', '-qam', 'guidance', exception: true)
      refute_equal first, files_fingerprint(root, Open3.capture2('git', '-C', root, 'rev-parse', 'HEAD').first.strip)
    end
  end

  def test_rejects_an_unknown_name
    _, error = capture_io { assert_equal 1, Shaka::Guidance.run(%w[other]) }
    assert_includes error, 'Usage: shaka guidance pr_evidence|merge_readiness'
  end
end
