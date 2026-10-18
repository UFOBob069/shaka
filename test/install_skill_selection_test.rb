# frozen_string_literal: true

require_relative 'companion_towers_support'
require 'json'

# Managed packages record one skill list whatever the flag order or repetition.
class InstallSkillSelectionTest < Minitest::Test
  include CompanionTowersSupport

  # Builds a package directly, bypassing the installer's name normalization.
  PACKAGE = <<~RUBY
    require 'fileutils'
    require 'shaka/installer'
    root, managed, *names = ARGV
    root = File.realpath(root)
    tree = Shaka::Install::Tree.new(names, source_root: root, source_alias: root)
    source = Shaka::Install::Source.new(root, names, tree)
    begin
      puts Shaka::Install::Package.new(FileUtils.mkdir_p(managed).first, source, names, tree).prepare(root)
    rescue ArgumentError => e
      abort e.message
    end
  RUBY

  def test_repeated_tower_flag_installs_valid_reusable_package
    output, status = install('--with-mct', '--with-mct')
    assert_predicate status, :success?, output
    assert_equal %w[shaka mct], metadata.fetch('skills')

    output, status = install('--with-mct', '--with-mct')
    assert_predicate status, :success?, output
  end

  def test_tower_flag_order_selects_one_package_and_rollback
    assert_predicate install('--with-mct', '--with-rct').last, :success?
    package = package_id

    assert_predicate install('--with-rct', '--with-mct').last, :success?
    assert_equal package, package_id
    assert_equal %w[shaka rct mct], metadata.fetch('skills')

    output, status = install('--with-mct', '--with-rct', '--rollback', package)
    assert_predicate status, :success?, output
  end

  # Packages from earlier releases recorded skills in flag order.
  def test_rollback_accepts_package_recorded_in_flag_order
    output, status = unnormalized_package(%w[shaka mct rct])
    assert_predicate status, :success?, output
    package = output.strip

    output, status = install('--with-rct', '--with-mct', '--rollback', File.basename(package))
    assert_predicate status, :success?, output
    assert_equal File.basename(package), package_id
  end

  def test_unknown_skill_is_refused_before_metadata_is_written
    FileUtils.mkdir_p(source('extra'))
    File.write(File.join(source('extra'), 'SKILL.md'), 'extra source')

    output, status = unnormalized_package(%w[shaka extra])
    refute_predicate status, :success?
    assert_equal "Managed package skills are invalid\n", output
    assert_empty Dir.children(managed_dir)
  end

  private

  def managed_dir = File.join(@home, '.local/share/shaka/installs')

  def unnormalized_package(names)
    library = File.expand_path('../skills/shaka/lib', __dir__)
    Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby, '-I', library, '-e', PACKAGE,
                    File.join(@directory, 'source'), managed_dir, *names)
  end

  def package_path = File.dirname(File.readlink(destination('shaka')), 2)

  def package_id = File.basename(package_path)

  def metadata = JSON.parse(File.read(File.join(package_path, '.shaka-install.json')))
end
