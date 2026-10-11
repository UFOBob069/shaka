# frozen_string_literal: true

require_relative 'official_install_support'

class OfficialInstallTest < Minitest::Test
  include OfficialInstallSupport

  def test_links_directly_to_chosen_checkout_and_reuses_recorded_location
    output, status = invoke('--directory', @root, '--repository', @remote, '--skills-dir', @skills_dir)
    assert_predicate status, :success?, output
    assert_includes output, 'Keep Shaka updated:'
    assert_includes output, 'install --update'
    assert_equal File.realpath(@source), File.readlink(@destination)
    output, status = invoke('--verify')
    assert_predicate status, :success?, output
    assert_empty git('-C', @root, 'status', '--porcelain')
  end

  def test_clones_into_the_default_location_and_links_all_requested_hosts
    output, status = invoke('--repository', @remote, '--agent', 'codex', '--agent', 'claude', '--agent', 'cursor')
    assert_predicate status, :success?, output
    assert_includes output, 'Keep Shaka updated:'
    assert_includes output, 'install --update'
    source = File.realpath(File.join(@home, '.agents/shaka'))
    %w[.agents .claude .cursor].each do |host|
      assert_equal File.join(source, 'skills/shaka'), File.readlink(File.join(@home, host, 'skills/shaka'))
    end
    assert_empty git('-C', source, 'status', '--porcelain')
  end

  def test_update_advances_same_checkout_and_preserves_links
    installed = File.join(@directory, 'dedicated installation')
    output, status = invoke('--directory', installed, '--repository', @remote, '--skills-dir', @skills_dir)
    assert_predicate status, :success?, output
    File.write(File.join(@source, 'SKILL.md'), 'updated skill')
    commit_source
    git('-C', @root, 'push', '-q', 'origin', 'main')
    output, status = invoke('--directory', installed, '--update')
    assert_predicate status, :success?, output
    assert_equal 'updated skill', File.read(File.join(@destination, 'SKILL.md'))
    assert_equal File.realpath(File.join(installed, 'skills/shaka')), File.readlink(@destination)
  end

  def test_registered_installation_keeps_its_previous_default_location
    installed = File.join(@home, '.local/share/shaka/source')
    output, status = invoke('--directory', installed, '--repository', @remote, '--agent', 'codex')
    assert_predicate status, :success?, output
    output, status = Open3.capture2e({ 'HOME' => @home }, RbConfig.ruby, File.join(installed, 'bin/install'),
                                     '--update')
    assert_predicate status, :success?, output
    link = File.join(@home, '.agents/skills/shaka')
    assert_equal File.realpath(File.join(installed, 'skills/shaka')), File.readlink(link)
    refute_path_exists File.join(@home, '.agents/shaka')
  end

  def test_divergent_remote_update_leaves_registered_revision_intact
    installed = File.join(@directory, 'installation')
    output, status = invoke('--directory', installed, '--repository', @remote, '--skills-dir', @skills_dir)
    assert_predicate status, :success?, output
    before = git('-C', installed, 'rev-parse', 'HEAD')
    diverge_origin
    output, status = invoke('--directory', installed, '--update')
    refute_predicate status, :success?
    assert_includes output, 'refusing to merge'
    assert_equal before, git('-C', installed, 'rev-parse', 'HEAD')
    assert_no_pending_revision(installed)
  end

  def test_update_refuses_dirty_installation_without_touching_links
    official_install
    previous = File.readlink(@destination)
    File.write(File.join(@root, 'personal.txt'), 'keep me')
    output, status = invoke('--update')
    refute_predicate status, :success?
    assert_includes output, 'dirty'
    assert_equal previous, File.readlink(@destination)
    assert_equal 'keep me', File.read(File.join(@root, 'personal.txt'))
  end

  def test_update_refuses_unexpected_origin_branch_and_revision
    official_install
    git('-C', @root, 'config', 'remote.origin.url', 'https://example.com/other.git')
    assert_refusal('origin')
    git('-C', @root, 'config', 'remote.origin.url', @remote)
    git('-C', @root, 'switch', '-qc', 'development')
    assert_refusal('branch')
    git('-C', @root, 'switch', '-q', 'main')
    File.write(File.join(@root, 'new.txt'), 'local commit')
    commit_source
    assert_refusal('revision changed')
  end

  def test_verification_is_read_only_and_detects_missing_links
    official_install
    record = File.join(@root, '.git/shaka-install.json')
    before = File.binread(record)
    File.unlink(@destination)
    output, status = invoke('--verify')
    refute_predicate status, :success?
    assert_includes output, 'link differs'
    assert_equal before, File.binread(record)
    refute_path_exists @destination
  end

  private

  def diverge_origin
    git('-C', @root, '-c', 'user.name=T', '-c', 'user.email=t@x', 'commit', '--amend', '-qm', 'different history')
    git('-C', @root, 'push', '--force', '-q', 'origin', 'main')
  end

  def assert_no_pending_revision(root)
    refute JSON.parse(File.read(File.join(root, '.git/shaka-install.json'))).key?('pending_revision')
  end
end
