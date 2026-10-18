# frozen_string_literal: true

require_relative 'companion_towers_support'

class InstallCompanionTowersTest < Minitest::Test
  include CompanionTowersSupport

  def test_installs_both_tower_skills_beside_shaka
    output, status = install('--with-claude-towers')

    assert_predicate status, :success?, output
    %w[shaka mct-claude rct-claude].each { |name| assert_linked(name) }
  end

  # The Codex tower drives native tools Claude Code does not have, so one flag never implies the other.
  def test_claude_towers_do_not_install_the_codex_repository_tower
    assert_predicate install('--with-claude-towers').last, :success?
    %w[rct mct].each { |name| refute_path_exists destination(name) }
  end

  def test_codex_repository_tower_omits_master_and_claude_towers
    assert_predicate install('--with-rct').last, :success?
    %w[mct mct-claude rct-claude].each { |name| refute_path_exists destination(name), name }
  end

  def test_default_install_omits_every_tower
    assert_predicate install.last, :success?
    %w[rct mct mct-claude rct-claude].each { |name| refute_path_exists destination(name), name }
  end

  # A partial install would leave one tower skill linked and the other silently missing.
  def test_preflight_refuses_before_linking_any_skill
    FileUtils.mkdir_p(destination('mct-claude'))
    marker = File.join(destination('mct-claude'), 'keep')
    File.write(marker, 'user content')

    refute_predicate install('--with-claude-towers').last, :success?
    refute_path_exists destination('shaka')
    assert_equal 'user content', File.read(marker)
  end

  def test_codex_master_is_independent_of_repository_and_claude_towers
    output, status = install('--with-mct')
    assert_predicate status, :success?, output
    %w[shaka mct].each { |name| assert_linked(name) }
    %w[rct mct-claude rct-claude].each { |name| refute_path_exists destination(name) }
  end

  def test_codex_towers_can_be_installed_together
    output, status = install('--with-rct', '--with-mct')
    assert_predicate status, :success?, output
    %w[shaka rct mct].each { |name| assert_linked(name) }
  end

  def test_master_conflict_preserves_user_files_before_linking
    FileUtils.mkdir_p(destination('mct'))
    marker = File.join(destination('mct'), 'keep')
    File.write(marker, 'user content')

    refute_predicate install('--with-mct').last, :success?
    refute_path_exists destination('shaka')
    assert_equal 'user content', File.read(marker)
  end
end
