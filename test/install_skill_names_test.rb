# frozen_string_literal: true

require_relative 'install_support'
require 'json'

class InstallSkillNamesTest < Minitest::Test
  include InstallTestSupport

  def test_repeated_flag_publishes_unique_skills_and_doctor_accepts_them
    prepare_towers
    output, status = run_installer('--skills-dir', @skills_dir, '--managed', '--with-mct', '--with-mct')

    assert_predicate status, :success?, output
    assert_equal %w[shaka mct], package_identity.fetch('skills')
    assert_doctor_accepts(%w[shaka mct])
  end

  def test_flag_order_publishes_one_package
    prepare_towers
    first = publish('--with-mct', '--with-rct')
    second = publish('--with-rct', '--with-mct')

    assert_equal first, second
    assert_equal %w[shaka rct mct], package_identity.fetch('skills')
    assert_equal [first], package_directories
  end

  def test_rollback_accepts_the_other_flag_order
    prepare_towers
    original = publish('--with-mct', '--with-rct')
    revise_shaka
    refute_equal original, publish('--with-rct', '--with-mct')

    output, status = rollback(original, '--with-rct', '--with-mct')
    assert_predicate status, :success?, output
    assert_equal original, File.basename(package_path)
    assert_equal @shaka_text, File.read(File.join(@destination, 'SKILL.md'))
  end

  private

  def prepare_towers
    replace_fixture_with_full_skill
    %w[mct rct].each do |name|
      destination = File.join(@directory, 'source', 'skills', name)
      FileUtils.rm_rf(destination)
      FileUtils.cp_r(File.expand_path("../skills/#{name}", __dir__), destination)
    end
  end

  def publish(*flags)
    output, status = run_installer('--skills-dir', @skills_dir, '--managed', *flags)
    assert_predicate status, :success?, output
    package_identity.fetch('package_id')
  end

  def revise_shaka
    skill = File.join(@directory, 'source', 'skills', 'shaka', 'SKILL.md')
    @shaka_text = File.read(skill)
    File.write(skill, 'version two')
  end

  def rollback(id, *flags)
    run_installer('--skills-dir', @skills_dir, '--managed', *flags, '--rollback', id)
  end

  def package_directories
    root = File.dirname(package_path)
    Dir.children(root).select { |name| File.directory?(File.join(root, name)) }.sort
  end

  def assert_doctor_accepts(skills)
    worktree = File.join(@directory, 'doctor-worktree')
    FileUtils.mkdir_p(worktree)
    output, status = Open3.capture2e(File.join(@destination, 'scripts', 'shaka'), 'doctor',
                                     '--installation-json', chdir: worktree)
    assert_predicate status, :success?, output
    assert_equal skills, JSON.parse(output).fetch('skills')
  end
end
