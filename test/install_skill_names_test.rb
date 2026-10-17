# frozen_string_literal: true

require_relative 'install_support'
require 'json'
require 'shaka/install/package'
require 'shaka/install/source'
require 'shaka/install/tree'

module InstallSkillNameFixtures
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

  def rollback(id, *flags)
    run_installer('--skills-dir', @skills_dir, '--managed', *flags, '--rollback', id)
  end
end

class InstallSkillNamesTest < Minitest::Test
  include InstallTestSupport
  include InstallSkillNameFixtures

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

  def test_noncanonical_order_is_refused_before_metadata_is_written
    prepare_towers
    managed = File.join(@directory, 'managed')
    error = assert_raises(ArgumentError) { prepare_package(managed, %w[shaka mct rct]) }

    assert_includes error.message, 'Managed package skills are invalid'
    refute_path_exists File.join(managed, '.shaka-install.json')
    assert_empty Dir.glob(File.join(managed, '**', '.shaka-install.json'))
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

  def revise_shaka
    skill = File.join(@directory, 'source', 'skills', 'shaka', 'SKILL.md')
    @shaka_text = File.read(skill)
    File.write(skill, 'version two')
  end

  def prepare_package(managed, names)
    root = File.join(@directory, 'source')
    tree = Shaka::Install::Tree.new(names)
    source = Shaka::Install::Source.new(root, names, tree)
    Shaka::Install::Package.new(managed, source, names, tree).prepare(root)
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

class InstallRecordedSkillOrderTest < Minitest::Test
  include InstallTestSupport
  include InstallSkillNameFixtures

  def test_rollback_accepts_an_older_package_recorded_in_flag_order
    prepare_towers
    publish('--with-mct', '--with-rct')
    rewritten = rewrite_recorded_order(%w[shaka mct rct])

    output, status = rollback(rewritten, '--with-rct', '--with-mct')
    assert_predicate status, :success?, output
    assert_equal rewritten, File.basename(package_path)
    assert_equal %w[shaka mct rct], package_identity.fetch('skills')
  end

  private

  def rewrite_recorded_order(names)
    directory = package_path
    metadata = reordered_metadata(directory, names)
    revised = metadata.fetch('package_id')
    File.write(File.join(directory, '.shaka-install.json'), "#{JSON.pretty_generate(metadata)}\n")
    revised_directory = File.join(File.dirname(directory), revised)
    File.rename(directory, revised_directory)
    relink(revised_directory)
    revised
  end

  def reordered_metadata(directory, names)
    metadata = package_identity
    metadata['skills'] = names
    metadata['source']['package_content_sha256'] = Shaka::Install::Tree.new(names).hash(directory)
    metadata['package_id'] = Shaka::Install::Package.identity_for(metadata.fetch('version'), metadata.fetch('source'))
    metadata
  end

  def relink(directory)
    %w[shaka mct rct].each do |name|
      link = File.join(@skills_dir, name)
      File.unlink(link) if File.symlink?(link)
      File.symlink(File.join(directory, 'skills', name), link)
    end
  end
end
