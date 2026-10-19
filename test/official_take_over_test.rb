# frozen_string_literal: true

require_relative 'official_take_over_support'

# A second checkout takes every host link from the registered one in one step.
class OfficialTakeOverTest < Minitest::Test
  include OfficialTakeOverSupport

  def test_take_over_moves_every_host_and_retires_the_old_record
    install_two_hosts
    output, status = invoke('--directory', @second, '--take-over')
    assert_predicate status, :success?, output
    assert_links_point_at(@second)
    assert_retired_and_registered
    output, status = Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby, File.join(@second, 'bin/install'), '--verify')
    assert_predicate status, :success?, output
  end

  # The refusal for a registered development clone prints this command; links in a custom directory still move.
  def test_the_printed_command_moves_links_in_a_custom_skills_directory
    official_install
    git('-C', @root, 'branch', 'topic')
    output, = invoke
    command = output[/--directory \S+ --take-over/]
    refute_nil command, output
    output, status = invoke('--directory', @second, '--take-over')
    assert_predicate status, :success?, output
    assert_equal File.join(File.realpath(@second), 'skills/shaka'), File.realpath(@destination)
  end

  def test_take_over_refuses_an_owner_other_accounts_can_write
    install_two_hosts
    git_directory = File.join(@root, '.git')
    File.chmod(0o777, git_directory)
    output, status = invoke('--directory', @second, '--take-over')
    refute_predicate status, :success?
    assert_includes output, 'group or world writable'
    refute_path_exists @second
  ensure
    File.chmod(0o755, git_directory)
  end

  # Another take-over can retire the owner after this one found it and before it took the locks.
  def test_take_over_refuses_an_owner_retired_meanwhile
    install_two_hosts
    output, status = Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby, '-r', retire_owner_first, @installer,
                                     '--directory', @second, '--take-over')
    refute_predicate status, :success?
    assert_includes output, 'is no longer registered'
    assert_links_point_at(@root)
  end

  def test_take_over_without_another_owner_refuses
    output, status = invoke('--directory', @second, '--take-over')
    refute_predicate status, :success?
    assert_includes output, 'No other registered checkout owns the Shaka links'
  end

  def test_take_over_rejects_maintenance_and_host_selection
    [%w[--take-over --update], %w[--take-over --agent codex]].each do |flags|
      output, status = invoke(*flags)
      refute_predicate status, :success?
      assert_includes output, 'Use --take-over alone'
    end
  end

  private

  def retire_owner_first
    path = File.join(@directory, 'retire_owner_first.rb')
    File.write(path, <<~RUBY)
      require #{File.join(@source, 'lib/shaka/install/official.rb').inspect}
      retire = Module.new { def take_over = File.rename("\#{@owner.root}/.git/shaka-install.json", "\#{@owner.root}/x") && super }
      Shaka::Install::Official.prepend(retire)
    RUBY
    path
  end

  def assert_retired_and_registered
    refute_path_exists File.join(@root, '.git/shaka-install.json')
    assert_equal 1, Dir.glob(File.join(@root, '.git/shaka-install.retired-*.json')).size
    record = JSON.parse(File.read(File.join(@second, '.git/shaka-install.json')))
    assert_equal [@remote, 2], [record['repository'], record['targets'].size]
  end
end
