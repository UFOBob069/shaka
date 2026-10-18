# frozen_string_literal: true

require_relative 'official_install_support'

class OfficialInstallIgnoreTest < Minitest::Test
  include OfficialInstallSupport

  def test_verify_and_update_skip_gitignored_files_under_the_skill
    official_install
    File.write(File.join(@root, '.git/info/exclude'), ".DS_Store\n")
    File.write(File.join(@root, 'skills/shaka/.DS_Store'), '')
    assert_empty git('-C', @root, 'status', '--porcelain', '--untracked-files=all')

    output, status = invoke('--verify')
    assert_predicate status, :success?, output
    output, status = invoke('--update')
    assert_predicate status, :success?, output
    assert_path_exists File.join(@root, 'skills/shaka/.DS_Store')
  end

  def test_verify_and_update_skip_a_directory_that_holds_only_ignored_files
    official_install
    File.write(File.join(@root, '.git/info/exclude'), ".DS_Store\n")
    FileUtils.mkdir_p(File.join(@root, 'skills/shaka/leftover/nested'))
    File.write(File.join(@root, 'skills/shaka/leftover/nested/.DS_Store'), '')
    assert_empty git('-C', @root, 'status', '--porcelain', '--untracked-files=all')

    output, status = invoke('--verify')
    assert_predicate status, :success?, output
    output, status = invoke('--update')
    assert_predicate status, :success?, output
  end

  def test_verify_still_refuses_an_empty_untracked_directory
    official_install
    File.write(File.join(@root, '.git/info/exclude'), ".DS_Store\n")
    FileUtils.mkdir_p(File.join(@root, 'skills/shaka/leftover/empty'))
    File.write(File.join(@root, 'skills/shaka/leftover/.DS_Store'), '')

    output, status = invoke('--verify')
    refute_predicate status, :success?
    assert_includes output, 'Installation files differ from the checkout revision'
  end

  def test_verify_reads_ignore_rules_from_the_checkout_despite_a_leaked_git_dir
    official_install
    File.write(File.join(@root, '.git/info/exclude'), ".DS_Store\n")
    File.write(File.join(@root, 'skills/shaka/.DS_Store'), '')
    other = File.join(@directory, 'other.git')
    git('init', '--bare', '-q', other)

    output, status = Open3.capture2e({ 'HOME' => @home, 'GIT_DIR' => other }, RbConfig.ruby, @installer, '--verify')
    assert_predicate status, :success?, output
  end
end
