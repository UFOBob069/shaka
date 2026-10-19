# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'rbconfig'
require 'shaka/update_check'

class UpdateCheckLaunchTest < Minitest::Test
  def test_trusted_wrapper_cannot_launch_a_candidate_interpreter
    Dir.mktmpdir('shaka-update-launch') do |directory|
      root, trusted, marker = prepare_wrapper(directory)
      with_path("#{root}/bin:#{trusted}:#{ENV.fetch('PATH')}") do
        Dir.chdir(root) { assert_safe_wrapper(marker) }
      end
    end
  end

  def test_subdirectory_cannot_launch_a_candidate_cli_or_interpreter
    Dir.mktmpdir('shaka-update-launch') do |directory|
      root, trusted, marker = prepare_wrapper(directory)
      write_executable(File.join(root, 'bin/gh'), "#!/bin/sh\nprintf ran > '#{marker}'\nprintf '{}'\n")
      with_path("#{root}/bin:#{trusted}:#{ENV.fetch('PATH')}") do
        Dir.chdir(File.join(root, 'src')) { assert_safe_wrapper(marker) }
      end
    end
  end

  def test_missing_cli_names_the_command_without_launching_a_process
    Dir.mktmpdir do |root|
      with_path(root) do
        error = Dir.chdir(root) { assert_raises(Shaka::UpdateCheck::Launch::Unavailable) { capture } }
        assert_equal 'gh_missing', error.reason
      end
    end
  end

  def test_nested_repository_does_not_narrow_the_candidate_boundary
    Dir.mktmpdir('shaka-update-launch') do |directory|
      root, trusted, marker = prepare_wrapper(directory)
      nested = prepare_nested_repository(root)
      write_executable(File.join(root, 'bin/gh'), "#!/bin/sh\nprintf ran > '#{marker}'\nprintf '{}'\n")
      with_path("#{root}/bin:#{trusted}:#{ENV.fetch('PATH')}") do
        Dir.chdir(nested) { assert_safe_wrapper(marker) }
      end
    end
  end

  # Outside every repository no pull request could have written the PATH, so the user's own gh runs.
  def test_outside_any_repository_the_check_still_runs
    Dir.mktmpdir('shaka-update-launch') do |directory|
      root, trusted, marker = prepare_wrapper(directory)
      File.delete(File.join(root, '.git'))
      with_path("#{trusted}:#{ENV.fetch('PATH')}") do
        Dir.chdir(File.join(root, 'src')) { assert_safe_wrapper(marker) }
      end
    end
  end

  def test_relative_path_entry_cannot_launch_a_cli_from_the_starting_folder
    Dir.mktmpdir('shaka-update-launch') do |directory|
      root, trusted, marker = prepare_wrapper(directory)
      File.delete(File.join(root, '.git'))
      write_executable(File.join(root, 'bin/gh'), "#!/bin/sh\nprintf ran > '#{marker}'\nprintf '{}'\n")
      with_path("bin::#{trusted}:#{ENV.fetch('PATH')}") do
        Dir.chdir(root) { assert_safe_wrapper(marker) }
      end
    end
  end

  private

  def capture = Shaka::UpdateCheck::Launch.capture(%w[gh api], Dir.tmpdir)

  def prepare_nested_repository(root)
    nested = File.join(root, 'vendor/sub')
    FileUtils.mkdir_p(nested)
    File.write(File.join(nested, '.git'), 'gitdir: /submodule/metadata')
    nested
  end

  def with_path(path)
    original = ENV.fetch('PATH')
    ENV['PATH'] = path
    yield
  ensure
    ENV['PATH'] = original
  end

  def assert_safe_wrapper(marker)
    output, _error, ok = capture
    refute_path_exists marker
    assert ok, output
    assert_equal 'identical', JSON.parse(output).fetch('status')
  end

  def prepare_wrapper(directory)
    root = File.join(directory, 'candidate')
    trusted = File.join(directory, 'trusted')
    marker = File.join(directory, 'candidate-ran')
    FileUtils.mkdir_p([File.join(root, 'bin'), File.join(root, 'src'), trusted])
    File.write(File.join(root, '.git'), 'gitdir: /registered/worktree/metadata')
    write_executable(File.join(root, 'bin/ruby'), "#!/bin/sh\nprintf ran > '#{marker}'\nprintf '{}'\n")
    write_executable(File.join(trusted, 'gh'), "#!/usr/bin/env ruby\nputs '{\"status\":\"identical\"}'\n")
    File.symlink(RbConfig.ruby, File.join(trusted, 'ruby'))
    [root, trusted, marker]
  end

  def write_executable(path, contents)
    File.write(path, contents)
    File.chmod(0o755, path)
  end
end
