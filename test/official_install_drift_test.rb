# frozen_string_literal: true

require_relative 'official_install_support'

# A user who pulls the installation checkout by hand should get a working update, not a dead end.
class OfficialInstallDriftTest < Minitest::Test
  include OfficialInstallSupport

  def test_update_records_a_pull_of_official_history
    official_install
    previous = File.readlink(@destination)
    pull_official_commit
    output, status = invoke('--update')
    assert_predicate status, :success?, output
    assert_recorded_pull(previous)
    output, status = invoke('--verify')
    assert_predicate status, :success?, output
  end

  def test_verify_names_the_update_command_after_a_pull
    official_install
    record = File.join(@root, '.git/shaka-install.json')
    before = File.binread(record)
    pull_official_commit
    output, status = invoke('--verify')
    refute_predicate status, :success?
    assert_includes output, 'install --update'
    assert_equal before, File.binread(record)
  end

  def test_update_refuses_a_pull_that_origin_no_longer_contains
    official_install
    recorded = git('-C', @root, 'rev-parse', 'HEAD').strip
    pull_official_commit
    pulled = git('-C', @root, 'rev-parse', 'HEAD').strip
    git('-C', @root, 'push', '--force', '-q', 'origin', "#{recorded}:main")
    output, status = invoke('--update')
    refute_predicate status, :success?
    assert_includes output, 'revision changed'
    assert_equal pulled, git('-C', @root, 'rev-parse', 'HEAD').strip
  end

  private

  def assert_recorded_pull(previous_link)
    record = JSON.parse(File.read(File.join(@root, '.git/shaka-install.json')))
    assert_equal git('-C', @root, 'rev-parse', 'HEAD').strip, record['revision']
    assert_equal 'pulled skill', File.read(File.join(@destination, 'SKILL.md'))
    assert_equal previous_link, File.readlink(@destination)
  end

  # Equivalent to `git pull` in the installation: the commit lands locally and on origin together.
  def pull_official_commit
    File.write(File.join(@source, 'SKILL.md'), 'pulled skill')
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
  end
end
