# frozen_string_literal: true

require_relative 'private_delivery_helper'
require 'shaka/opening_publication'

class PrivateOpeningSourceTest < Minitest::Test
  include PrivateDeliveryFixture

  def test_tracked_prompt_reads_trusted_bytes_after_a_fork_changes_it
    with_trial do
      prepare_tracked_prompt
      File.write(File.join(@root, 'opening.md'), 'Candidate instructions.')
      commit(@root)
      result = opening
      assert_includes result['prompt'], 'Trusted instructions.'
      refute_includes result['prompt'], 'Candidate instructions.'
    end
  end

  def test_invalid_candidate_prompt_cannot_block_valid_trusted_instructions
    with_trial do
      prepare_tracked_prompt
      files = input_files
      File.binwrite(File.join(@root, 'opening.md'), '')
      assert_trusted_prompt(files)
      File.unlink(File.join(@root, 'opening.md'))
      commit(@root)
      assert_trusted_prompt(files)
    end
  end

  def test_private_symlink_cannot_turn_a_tracked_candidate_prompt_into_local_instructions
    with_trial do
      prepare_tracked_prompt
      File.symlink('../../opening.md', File.join(@root, '.agents/shaka/opening.md'))
      update_private { |data| data['opening_check']['prompt_file'] = '.agents/shaka/opening.md' }
      result = opening
      assert_includes result['reason'], 'private settings tree'
    end
  end

  def test_candidate_only_prompt_is_not_an_instruction_source
    with_trial do
      File.write(File.join(@root, 'opening.md'), 'Candidate instructions.')
      commit(@root)
      update_private { |data| data['opening_check']['prompt_file'] = 'opening.md' }
      result = opening
      assert_includes result['reason'], 'does not name a file'
      refute_includes result['prompt'], 'Candidate instructions.'
    end
  end

  def test_private_prompt_and_opening_support_non_ascii_utf8
    with_trial do
      path = '.agents/shaka/opening.md'
      File.write(File.join(@root, path), 'Nommez le sujet — pour le lecteur.')
      update_private { |data| data['opening_check']['prompt_file'] = path }
      result = Shaka::OpeningPublication.new(root: @root, ref: @ref).call('La tâche est résolue.')
      assert_equal 'host_check', result['status']
      assert_includes result['prompt'], 'Nommez le sujet — pour le lecteur.'
    end
  end

  def test_fingerprint_includes_the_trusted_opening_dependency
    with_trial do
      prepare_tracked_prompt
      first_ref = @ref
      File.write(File.join(@root, 'opening.md'), 'Changed trusted instructions.')
      commit(@root)
      @ref = git(@root, 'rev-parse', 'HEAD')
      latest = input_files
      @ref = first_ref
      refute_equal latest, input_files
    end
  end

  private

  def assert_trusted_prompt(files)
    assert_reviewer('anthropic/claude')
    assert_includes opening['prompt'], 'Trusted instructions.'
    assert_equal files, input_files
  end

  def prepare_tracked_prompt
    File.write(File.join(@root, 'opening.md'), 'Trusted instructions. — é.')
    commit(@root)
    @ref = git(@root, 'rev-parse', 'HEAD')
    update_private { |data| data['opening_check']['prompt_file'] = 'opening.md' }
  end

  def opening = Shaka::OpeningPublication.new(root: @root, ref: @ref).call('La tâche est résolue.')

  def input_files
    _, fingerprint, = Shaka::Evidence::Inputs.capture(root: @root, ref: @ref, repository: 'owner/repo')
    fingerprint.fetch('components').fetch('files')
  end
end
