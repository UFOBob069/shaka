# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'seam_check_helpers'
require 'shaka/seam'

class SeamCheckModeTest < Minitest::Test
  include SeamCheckHelpers

  CheckReport = Shaka::Seam::CheckReport
  COMMAND = SeamCheckHelpers::COMMAND

  def test_help_documents_local_mode
    output, error, status = Open3.capture3(COMMAND, 'seam', 'check', '--help')

    assert_predicate status, :success?, error
    assert_includes output, '--local'
    assert_includes output, '--ref'
  end

  def test_local_check_labels_candidate_output_and_grants_no_authority
    with_repository do |root|
      File.write(File.join(root, '.agents/writing-style.md'), "Candidate style.\n")
      payload, error, status = capture_check(root, '--local')

      assert_predicate status, :success?, error
      refute_includes error, CheckReport::IMPLICIT_DIAGNOSTIC
      assert_local_candidate payload
      assert_equal 'auto', payload.dig('merge', 'preference')
      refute payload.key?('writing_style')
    end
  end

  def test_omitted_mode_warns_and_still_labels_candidate_output
    with_repository do |root|
      File.write(File.join(root, '.agents/writing-style.md'), "Candidate style.\n")
      payload, error, status = capture_check(root)

      assert_predicate status, :success?, error
      assert_includes error, CheckReport::IMPLICIT_DIAGNOSTIC
      assert_local_candidate payload
      refute payload.key?('writing_style')
    end
  end

  def test_ref_check_labels_trusted_policy_and_still_grants_no_merge_authority
    with_repository do |root|
      commit_repository(root)
      payload, error, status = capture_check(root, '--ref', 'HEAD')

      assert_predicate status, :success?, error
      refute_includes error, CheckReport::IMPLICIT_DIAGNOSTIC
      assert_trusted_policy payload
      refute payload.key?('writing_style')
    end
  end

  def test_ref_check_returns_the_writing_style_from_the_trusted_commit
    with_repository do |root|
      path = File.join(root, '.agents/writing-style.md')
      File.write(path, "Trusted style.\n")
      commit_repository(root)
      File.write(path, "Candidate style.\n")

      payload, error, status = capture_check(root, '--ref', 'HEAD')

      assert_predicate status, :success?, error
      assert_equal 'Trusted style.', payload.dig('writing_style', 'guide')
      refute payload.key?('writing_style_warning')
    end
  end

  def test_local_cannot_be_combined_with_ref
    with_repository do |root|
      _payload, error, status = capture_check(root, '--local', '--ref', 'HEAD')

      refute_predicate status, :success?
      assert_includes error, '--local cannot be combined with --ref'
    end
  end

  def test_required_check_does_not_apply_to_check
    with_repository do |root|
      _payload, error, status = capture_check(root, '--local', '--required-check', 'checks')

      refute_predicate status, :success?
      assert_includes error, 'init options do not apply to check'
    end
  end

  def test_local_does_not_apply_to_init
    Dir.mktmpdir('shaka-seam-init') do |root|
      _output, error, status = Open3.capture3(COMMAND, 'seam', 'init', '--root', root, '--local')

      refute_predicate status, :success?
      assert_includes error, '--local does not apply to init'
    end
  end

  private

  def assert_local_candidate(payload)
    validation = payload.fetch('validation')
    assert_equal CheckReport::LOCAL_MODE, validation.fetch('mode')
    assert_false validation.fetch('grants_policy')
    assert_false validation.fetch('grants_merge_authority')
    refute validation.key?('sha')
  end

  def assert_trusted_policy(payload)
    validation = payload.fetch('validation')
    assert_equal CheckReport::TRUSTED_MODE, validation.fetch('mode')
    assert_true validation.fetch('grants_policy')
    assert_false validation.fetch('grants_merge_authority')
    assert_equal 'HEAD', validation.fetch('ref')
    assert_match(/\A[0-9a-f]{40}\z/, validation.fetch('sha'))
  end
end

class SeamCheckWritingStyleTest < Minitest::Test
  include SeamCheckHelpers

  def test_local_check_rejects_an_empty_style
    with_repository do |root|
      File.write(File.join(root, '.agents/writing-style.md'), " \n")
      _payload, error, status = capture_check(root, '--local')

      refute_predicate status, :success?
      assert_includes error, '.agents/writing-style.md must not be empty'
    end
  end

  def test_ref_check_warns_and_omits_an_invalid_trusted_writing_style
    with_repository do |root|
      File.write(File.join(root, '.agents/writing-style.md'), " \n")
      commit_repository(root)
      payload, error, status = capture_check(root, '--ref', 'HEAD')

      assert_predicate status, :success?
      assert_includes error, '.agents/writing-style.md at'
      assert_equal 'auto', payload.dig('merge', 'preference')
      refute payload.key?('writing_style')
      assert_includes payload.fetch('writing_style_warning'), 'must not be empty'
    end
  end
end

class CandidateWritingStyleTest < Minitest::Test
  include SeamCheckHelpers

  def test_rejects_a_symlink
    with_repository do |root|
      File.write(File.join(root, 'style.md'), "Style.\n")
      File.symlink('../style.md', File.join(root, '.agents/writing-style.md'))

      assert_invalid_style(root, 'must be a regular file, not a symlink')
    end
  end

  def test_rejects_a_directory
    with_repository do |root|
      FileUtils.mkdir_p(File.join(root, '.agents/writing-style.md'))

      assert_invalid_style(root, 'must be a regular file')
    end
  end

  def test_rejects_an_oversized_file
    with_repository do |root|
      File.write(File.join(root, '.agents/writing-style.md'), 'x' * (Shaka::WritingStyle::MAX_BYTES + 1))

      assert_invalid_style(root, "must not exceed #{Shaka::WritingStyle::MAX_BYTES} bytes")
    end
  end

  def test_accepts_a_file_at_the_exact_size_limit
    with_repository do |root|
      File.write(File.join(root, '.agents/writing-style.md'), 'x' * Shaka::WritingStyle::MAX_BYTES)
      payload, error, status = capture_check(root, '--local')

      assert_predicate status, :success?, error
      refute payload.key?('writing_style')
    end
  end

  def test_rejects_non_utf8_content
    with_repository do |root|
      File.binwrite(File.join(root, '.agents/writing-style.md'), "Valid\n\xFF".b)

      assert_invalid_style(root, 'must contain valid UTF-8')
    end
  end

  def test_wraps_a_read_error
    with_repository do |root|
      File.write(File.join(root, '.agents/writing-style.md'), "Style.\n")
      original = File.method(:binread)
      File.define_singleton_method(:binread) { |*| raise Errno::EACCES }

      error = assert_raises(Shaka::Error) { Shaka::WritingStyle.validate_candidate(root:) }
      assert_includes error.message, 'Cannot read .agents/writing-style.md: Errno::EACCES'
    ensure
      File.define_singleton_method(:binread, original) if original
    end
  end

  private

  def assert_invalid_style(root, expected)
    _payload, error, status = capture_check(root, '--local')
    refute_predicate status, :success?
    assert_includes error, expected
  end
end
