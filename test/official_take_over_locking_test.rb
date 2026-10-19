# frozen_string_literal: true

require 'English'
require_relative 'official_take_over_support'

# Concurrent take-overs and installs wait for each other instead of undoing or deadlocking.
class OfficialTakeOverLockingTest < Minitest::Test
  include OfficialTakeOverSupport

  # Each runs from a checkout that owns some links, so each finds the other as the owner.
  def test_opposite_take_overs_finish
    install_opposite_owners
    pids = [@root, @second].map { |directory| spawn_installer('--directory', directory, '--take-over') }
    assert_equal [true, true], finished(pids), installer_logs
  end

  # A take-over waiting for one checkout lock must not hold the other, or two opposite ones deadlock.
  def test_a_waiting_take_over_holds_no_checkout_lock
    install_opposite_owners
    File.open(File.join(@second, '.git/.shaka-install.lock'), File::RDWR) do |lock|
      lock.flock(File::LOCK_EX)
      pid = spawn_installer('--directory', @root, '--take-over')
      sleep 3
      assert File.open(File.join(@root, '.git/.shaka-install.lock'), File::RDWR) { |own| own.flock(File::LOCK_EX | File::LOCK_NB) }
      lock.flock(File::LOCK_UN)
      assert_equal [true], finished([pid]), installer_logs
    end
  end

  def test_take_over_switches_no_host_until_it_holds_every_host_lock
    install_two_hosts
    File.open(File.join(File.dirname(@claude), '.shaka-install.lock'), File::RDWR) do |lock|
      lock.flock(File::LOCK_EX)
      pid = spawn_take_over
      assert_links_point_at(@root)
      lock.flock(File::LOCK_UN)
      Process.wait(pid)
    end
    assert_predicate $CHILD_STATUS, :success?, installer_logs
    assert_links_point_at(@second)
  end

  private

  # The first checkout owns the Codex link and the second owns the Claude link.
  def install_opposite_owners
    git('clone', '-q', '--branch', 'main', @remote, @second)
    [[@root, 'codex'], [@second, 'claude']].each do |directory, agent|
      output, status = invoke('--directory', directory, '--repository', @remote, '--agent', agent)
      assert_predicate status, :success?, output
    end
  end

  # Returns once the take-over has recorded its Ruby, just before it takes the host locks.
  def spawn_take_over
    pid = spawn_installer('--directory', @second, '--take-over')
    wait_for { File.exist?(File.join(@second, '.git/shaka-ruby')) }
    sleep 1
    pid
  end

  # Keeps each child's output so a failure on another machine shows why the installer stopped.
  def spawn_installer(*)
    log = File.join(@directory, "installer-#{Dir.glob(File.join(@directory, 'installer-*.log')).size}.log")
    Process.spawn({ 'HOME' => @home }, RbConfig.ruby, @installer, *, %i[out err] => log)
  end

  def installer_logs = Dir.glob(File.join(@directory, 'installer-*.log')).map { |log| File.read(log) }.join("\n")

  # Exit success of each process, or a failed assertion after a minute so a deadlock cannot hang the suite.
  def finished(pids)
    statuses = {}
    wait_for { statuses.merge!(reaped(pids - statuses.keys)).size == pids.size }
    pids.map { |pid| statuses.fetch(pid).success? }
  ensure
    (pids - statuses.keys).each { |pid| stop(pid) }
  end

  def reaped(pids) = pids.filter_map { |pid| Process.wait2(pid, Process::WNOHANG) }.to_h

  def stop(pid)
    Process.kill('KILL', pid)
    Process.wait(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end
end
