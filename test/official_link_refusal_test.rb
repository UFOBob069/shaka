# frozen_string_literal: true

require 'shellwords'
require_relative 'install_refusal_support'

# Link, Ruby, and file-mode refusals name what they found, and their next command clears it.
class OfficialLinkRefusalTest < Minitest::Test
  include InstallRefusalSupport

  def test_missing_ruby_names_the_record_and_reinstall_keeps_the_skills
    official_install
    record = File.join(@root, '.git/shaka-ruby')
    File.write(record, "/missing/ruby\n")
    output = refusal('--verify', "Shaka's installation Ruby is unavailable", '/missing/ruby, recorded in',
                     "shaka in #{@skills_dir}")
    run_next(output)
    assert_succeeds('--verify')
    assert_equal File.realpath(RbConfig.ruby), File.read(record).strip
  end

  def test_missing_link_names_its_target_and_reinstall_restores_it
    official_install
    File.unlink(@destination)
    output = refusal('--verify', "Installation link is missing: #{@destination}",
                     "it should point to #{File.join(checkout, 'skills/shaka')}")
    run_next(output)
    assert_succeeds('--verify')
  end

  def test_link_to_another_installation_names_its_owner
    official_install
    other = register_second_installation(File.join(@directory, 'other skills'))
    File.unlink(@destination)
    File.symlink(File.join(other, 'skills/shaka'), @destination)
    output = refusal('--verify', "Installation link differs: #{@destination}", "the installation at #{other}",
                     "follows the registered branch (origin/main of #{@remote})",
                     'a person must decide which installation to keep')
    run_next(output)
    assert_succeeds('--verify')
  end

  def test_second_installation_names_the_owner_of_the_existing_link
    official_install
    other = File.join(@directory, 'second')
    output, status = second_install(other, @skills_dir)
    refute_predicate status, :success?
    assert_includes output, "Refusing existing destination: #{@destination}"
    assert_includes output, "the installation at #{checkout}"
    run_next(output)
    output, status = second_install(other, @skills_dir)
    assert_predicate status, :success?, output
  end

  def test_existing_directory_is_moved_aside
    FileUtils.mkdir_p(@destination)
    output, status = invoke('--directory', @root, '--repository', @remote, '--skills-dir', @skills_dir)
    refute_predicate status, :success?
    assert_includes output, "Refusing existing destination: #{@destination}. Found: it is a directory, not a skill link"
    run_next(output)
    official_install
    assert_path_exists "#{@destination}.before-shaka"
  end

  def test_moving_aside_never_replaces_an_earlier_backup
    FileUtils.mkdir_p(@destination)
    File.write("#{@destination}.before-shaka", 'earlier backup')
    output, status = invoke('--directory', @root, '--repository', @remote, '--skills-dir', @skills_dir)
    refute_predicate status, :success?
    assert_includes output, "#{Shellwords.escape(@destination)}.before-shaka-2"
    run_next(output)
    assert_equal 'earlier backup', File.read("#{@destination}.before-shaka")
    assert File.directory?("#{@destination}.before-shaka-2")
  end

  def test_writable_skill_files_are_listed_and_chmod_clears_them
    official_install
    File.chmod(0o664, File.join(@source, 'SKILL.md'))
    output = refusal('--verify', 'Installation skills are group or world writable',
                     File.join(checkout, 'skills/shaka/SKILL.md'))
    run_next(output)
    assert_succeeds('--verify')
  end

  private

  def second_install(directory, skills_dir)
    clone = File.join(@directory, 'second-source')
    git('clone', '-q', '-b', 'main', @remote, clone) unless File.directory?(clone)
    Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby, File.join(clone, 'bin/install'),
                    '--directory', directory, '--repository', @remote, '--skills-dir', skills_dir)
  end

  def register_second_installation(skills_dir)
    directory = File.join(@directory, 'second')
    output, status = second_install(directory, skills_dir)
    assert_predicate status, :success?, output
    File.realpath(directory)
  end
end
