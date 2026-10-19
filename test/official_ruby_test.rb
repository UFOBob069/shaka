# frozen_string_literal: true

require_relative 'install_refusal_support'

class OfficialRubyTest < Minitest::Test
  include InstallRefusalSupport

  def setup
    super
    FileUtils.rm_rf(@source)
    FileUtils.cp_r(File.expand_path('../skills/shaka', __dir__), @source)
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
    official_install
    @helper = File.join(@destination, 'scripts/shaka')
  end

  def test_helper_and_verification_use_recorded_ruby_outside_the_installation
    fake = File.join(@directory, 'fake-bin')
    FileUtils.mkdir_p(fake)
    File.write(File.join(fake, 'ruby'), "#!/bin/sh\necho project-ruby >&2; exit 1\n")
    File.chmod(0o755, File.join(fake, 'ruby'))
    environment = { 'PATH' => "#{fake}:#{ENV.fetch('PATH')}", 'RUBYOPT' => '-rmissing_project_bundler' }
    output, status = Open3.capture2e(environment, @helper, 'install', '--verify', chdir: @directory)
    assert_predicate status, :success?, output
    assert_includes output, 'Verified Shaka installation'
  end

  def test_doctor_identifies_the_official_checkout
    output, status = Open3.capture2e(@helper, 'doctor', '--installation-json', chdir: @directory)
    assert_predicate status, :success?, output
    identity = JSON.parse(output)
    assert_equal 'revision', identity.fetch('source').fetch('kind')
    assert_equal git('-C', @root, 'rev-parse', 'HEAD').strip, identity.fetch('source').fetch('revision')
  end

  def test_missing_recorded_ruby_refuses_project_fallback
    File.unlink(File.join(@root, '.git/shaka-ruby'))
    output, status = Open3.capture2e(@helper, 'install', '--verify')
    refute_predicate status, :success?
    assert_includes output, 'installation Ruby is unavailable'
  end

  def test_launcher_names_the_missing_ruby_and_the_reinstall_command
    File.write(File.join(@root, '.git/shaka-ruby'), "/missing/ruby\n")
    output, status = Open3.capture2e({ 'HOME' => @home }, @helper, 'install', '--verify')
    refute_predicate status, :success?
    assert_includes output, "/missing/ruby, recorded in #{checkout}/.git/shaka-ruby"
    run_next(output)
    output, status = Open3.capture2e({ 'HOME' => @home }, @helper, 'install', '--verify')
    assert_predicate status, :success?, output
  end

  def test_launcher_command_survives_an_apostrophe_in_the_path
    installed = File.join(@directory, "o'connor")
    output, status = invoke('--directory', installed, '--repository', @remote, '--skills-dir',
                            File.join(@directory, 'other skills'))
    assert_predicate status, :success?, output
    File.write(File.join(installed, '.git/shaka-ruby'), "/missing/ruby\n")
    helper = File.join(installed, 'skills/shaka/scripts/shaka')
    run_next(helper_verify(helper, success: false))
    helper_verify(helper)
  end

  private

  def helper_verify(helper, success: true)
    output, status = Open3.capture2e({ 'HOME' => @home }, helper, 'install', '--verify')
    assert_equal success, status.success?, output
    output
  end
end
