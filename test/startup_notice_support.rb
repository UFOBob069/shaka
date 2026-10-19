# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'rbconfig'
require 'shaka/startup_notice'
require 'shaka/update_check'

# Fake checkouts and host links in a temporary home for startup notice tests.
module StartupNoticeSupport
  NOW = Time.utc(2026, 10, 18, 12)
  LIBRARY = File.expand_path('../skills/shaka/lib', __dir__)
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  def setup
    @directory = Dir.mktmpdir('startup-notice')
    @home = File.join(@directory, 'home')
    @root = checkout('installed', registered: true)
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  private

  def checkout(name, registered:)
    root = File.join(@directory, name)
    FileUtils.mkdir_p([File.join(root, 'skills/shaka/scripts'), File.join(root, '.git')])
    File.write(File.join(root, '.git/shaka-install.json'), '{}') if registered
    File.realpath(root)
  end

  def link(directory, root)
    FileUtils.mkdir_p(File.join(@home, directory))
    File.symlink(File.join(root, 'skills/shaka'), File.join(@home, directory, 'shaka'))
  end

  # Every command a process could run here only leaves a mark, so any command or request would show.
  def fake_commands
    bin = File.join(@directory, 'bin')
    FileUtils.mkdir_p(bin)
    %w[git gh curl].each do |name|
      File.write(File.join(bin, name), "#!/bin/sh\ntouch #{ran}\n")
      File.chmod(0o755, File.join(bin, name))
    end
    bin
  end

  def ran = File.join(@directory, 'ran')

  def answer(status) = { 'status' => status, 'guidance' => "#{status} guidance" }

  def remember(status, at:)
    Shaka::UpdateCheck::Cache.record(@root, answer(status), home: @home, now: at)
  end

  def notice(root: @root, now: NOW)
    line = Shaka::StartupNotice.new(home: @home, root:, now:).line
    line && "shaka: #{line}"
  end
end
