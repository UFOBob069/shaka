# frozen_string_literal: true

require_relative 'official_install_support'
require 'shaka/executable_file'
require 'shellwords'

class OfficialUpdateTest < Minitest::Test
  include OfficialInstallSupport

  def test_invalid_incoming_skill_does_not_advance_the_live_checkout
    skip 'this platform does not store an executable bit' if Shaka::ExecutableFile.windows?

    installed = cloned_installation
    before = git('-C', installed, 'rev-parse', 'HEAD')
    File.chmod(0o644, File.join(@source, 'scripts/shaka'))
    push_source
    output, status = invoke('--directory', installed, '--update')
    refute_predicate status, :success?
    assert_includes output, 'not executable'
    assert_equal before, git('-C', installed, 'rev-parse', 'HEAD')
    assert_equal 'version one', File.read(File.join(@destination, 'SKILL.md'))
    assert_single_worktree(installed)
  end

  def test_incoming_helper_failure_leaves_the_working_installation_available
    installed = cloned_installation
    before = git('-C', installed, 'rev-parse', 'HEAD')
    File.write(File.join(@source, 'scripts/shaka'), "#!/bin/sh\nexit 1\n")
    push_source
    output, status = invoke('--directory', installed, '--update')
    refute_predicate status, :success?
    assert_includes output, 'helper failed verification'
    assert_equal before, git('-C', installed, 'rev-parse', 'HEAD')
  end

  def test_interrupted_known_update_resumes
    installed = cloned_installation
    File.write(File.join(@source, 'SKILL.md'), 'updated skill')
    push_source
    output, status = interrupt_after_merge(installed)
    refute_predicate status, :success?, output
    output, status = invoke('--directory', installed, '--update')
    assert_predicate status, :success?, output
    assert_equal 'updated skill', File.read(File.join(@destination, 'SKILL.md'))
    refute JSON.parse(File.read(File.join(installed, '.git/shaka-install.json'))).key?('pending_revision')
  end

  private

  def push_source
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
  end

  def assert_single_worktree(root)
    assert_equal 1, git('-C', root, 'worktree', 'list', '--porcelain').scan(/^worktree /).size
  end

  def cloned_installation
    installed = File.join(@directory, 'installation')
    output, status = invoke('--directory', installed, '--repository', @remote, '--skills-dir', @skills_dir)
    assert_predicate status, :success?, output
    installed
  end

  def interrupt_after_merge(installed)
    bin = File.join(@directory, 'interrupt-bin')
    FileUtils.mkdir_p(bin)
    File.write(File.join(bin, 'git'), "#!/bin/sh\ncase \" $* \" in\n*' merge '*) " \
                                      "#{Shellwords.escape(TEST_GIT)} \"$@\" || exit $?; kill -KILL \"$PPID\";;\n" \
                                      "*) exec #{Shellwords.escape(TEST_GIT)} \"$@\";;\nesac\n")
    File.chmod(0o755, File.join(bin, 'git'))
    Open3.capture2e({ 'HOME' => @home, 'PATH' => "#{bin}:#{ENV.fetch('PATH')}" },
                    RbConfig.ruby, @installer, '--directory', installed, '--update')
  end
end
