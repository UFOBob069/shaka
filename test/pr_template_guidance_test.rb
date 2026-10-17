# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require_relative 'project_guidance_helper'

class PrTemplateGuidanceTest < Minitest::Test
  include RepositoryConfigTestHelpers
  include ProjectGuidanceHelper

  def test_pr_evidence_adds_the_trusted_pull_request_template
    with_guidance(GUIDANCE) do |root|
      write_template(root, 'Trusted template.')
      sha = commit(root)
      write_template(root, 'Candidate template.')
      assert_equal "Trusted pr_evidence.\n\n---\n\nPull request template (.github/pull_request_template.md):\n\n" \
                   'Trusted template.', guidance('pr_evidence', root, sha)
      assert_equal 'Trusted merge_readiness.', guidance('merge_readiness', root, sha)
    end
  end

  def test_candidate_only_template_is_not_read
    with_guidance(GUIDANCE) do |root|
      sha = commit(root)
      write_template(root, 'Candidate template.')
      assert_equal 'Trusted pr_evidence.', guidance('pr_evidence', root, sha)
    end
  end

  def test_template_alone_does_not_configure_pr_evidence
    with_repository do |root|
      write_template(root, 'Trusted template.')
      error = assert_raises(Shaka::Error) { guidance('pr_evidence', root, commit(root)) }
      assert_equal 'project_guidance.pr_evidence is not configured', error.message
    end
  end

  def test_a_guide_naming_the_template_prints_it_once
    with_guidance('pr_evidence' => '.github/pull_request_template.md') do |root|
      assert_equal 'Trusted pr_evidence.', guidance('pr_evidence', root, commit(root))
    end
  end

  def test_a_broken_template_is_skipped_and_the_guide_still_prints
    with_guidance(GUIDANCE) do |root|
      write_template(root, '')
      output = guidance('pr_evidence', root, commit(root))
      assert output.start_with?("Trusted pr_evidence.\n\n---\n\nPull request template skipped: ")
      assert_includes output, 'is empty'
    end
  end

  def test_a_guide_naming_another_template_location_skips_the_found_template
    with_guidance('pr_evidence' => 'docs/pull_request_template.md') do |root|
      write_template(root, 'Root template.')
      assert_equal 'Trusted pr_evidence.', guidance('pr_evidence', root, commit(root))
    end
  end

  def test_unusable_templates_leave_the_guide_and_fingerprint_working
    with_guidance(GUIDANCE) do |root|
      write_template(root, '')
      sha = commit(root)
      refute_empty files_fingerprint(root, sha)
      File.delete(File.join(root, '.github/pull_request_template.md'))
      File.symlink('pull_request_template.md', File.join(root, '.github/pull_request_template.md'))
      git_commit(root)
      assert_equal 'Trusted pr_evidence.', guidance('pr_evidence', root, head(root))
      refute_empty files_fingerprint(root, head(root))
    end
  end

  def test_committed_template_change_updates_the_files_fingerprint
    with_guidance(GUIDANCE) do |root|
      write_template(root, 'First template.')
      first = files_fingerprint(root, commit(root))
      write_template(root, 'Second template.')
      git_commit(root)
      refute_equal first, files_fingerprint(root, head(root))
    end
  end
end
