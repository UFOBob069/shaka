# frozen_string_literal: true

require_relative 'private_delivery_helper'
require 'shaka/guidance'

class PrivateGuidanceSourceTest < Minitest::Test
  include PrivateDeliveryFixture

  def test_individual_setup_reads_its_untracked_guidance
    with_trial do
      File.write(File.join(@root, '.agents/shaka/merge-readiness.md'), 'Private requirement — é.')
      update_private { |data| data['project_guidance'] = { 'merge_readiness' => '.agents/shaka/merge-readiness.md' } }
      assert_equal 'Private requirement — é.', guidance
    end
  end

  def test_tracked_guidance_reads_trusted_bytes_after_a_fork_changes_it
    with_trial do
      File.write(File.join(@root, 'merge-readiness.md'), 'Trusted requirement.')
      commit(@root)
      @ref = git(@root, 'rev-parse', 'HEAD')
      update_private { |data| data['project_guidance'] = { 'merge_readiness' => 'merge-readiness.md' } }
      File.write(File.join(@root, 'merge-readiness.md'), 'Candidate requirement.')
      commit(@root)
      assert_equal 'Trusted requirement.', guidance
    end
  end

  def test_individual_setup_reads_the_template_at_the_trusted_commit
    with_trial do
      write_template('Trusted template.')
      commit(@root)
      @ref = git(@root, 'rev-parse', 'HEAD')
      File.write(File.join(@root, '.agents/shaka/pr-evidence.md'), 'Private evidence.')
      update_private { |data| data['project_guidance'] = { 'pr_evidence' => '.agents/shaka/pr-evidence.md' } }
      write_template('Candidate template.')
      assert_equal "Private evidence.\n\n---\n\nPull request template (.github/pull_request_template.md):\n\n" \
                   'Trusted template.', guidance('pr_evidence')
    end
  end

  private

  def guidance(name = 'merge_readiness') = Shaka::Guidance.new(name:, root: @root, ref: @ref).call

  def write_template(text)
    FileUtils.mkdir_p(File.join(@root, '.github'))
    File.write(File.join(@root, '.github/pull_request_template.md'), text)
  end
end
