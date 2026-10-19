# frozen_string_literal: true

require_relative 'install_scenario_support'

# States that sit next to each other in the install matrix, where status once named the wrong one
# or a next step that could not run.
class InstallStatusEdgesTest < Minitest::Test
  include InstallScenarioSupport

  # A record that still reaches one host keeps working there, so it must not be called an orphan.

  def test_a_record_with_one_moved_link_is_not_an_orphan
    root = default_install('--agent', 'codex', '--agent', 'claude')
    File.unlink(File.join(@home, '.claude/skills/shaka'))
    run_install(@root, '--directory', @root, '--repository', @remote, '--agent', 'claude')
    report = status(root)
    assert_equal 'B9', report['state']
    refute_includes report['findings'].map { |item| item['id'] }, 'C1'
    assert_includes report['decision'], 'Choose which install'
  end

  def test_a_link_to_another_skill_in_the_checkout_is_repointed
    root = default_install('--with-rct')
    link = File.join(@home, '.agents/skills/shaka')
    File.unlink(link)
    File.symlink(File.join(root, 'skills/rct'), link)
    report = status(root)
    assert_equal 'B9', report['state']
    assert_includes report['next_command'],
                    "ln -sfn #{Shellwords.escape(File.join(File.realpath(root), 'skills/shaka'))}"
  end

  def test_a_missing_tracking_ref_is_not_called_a_rewrite
    root = default_install
    git('-C', root, 'update-ref', '-d', 'refs/remotes/origin/main')
    report = status(root)
    refute_includes report['findings'].map { |item| item['id'] }, 'B6'
    assert_includes report['next_command'], 'fetch origin main'
  end

  # The update step must actually recover a pulled checkout whose recorded Ruby is gone.
  def test_the_update_step_recovers_without_the_recorded_ruby
    root = pulled_without_ruby
    step = status(root).values_at('state', 'next_command')
    assert_equal ['B1', "#{Shellwords.escape(File.join(File.realpath(root), 'bin/install'))} --update"], step
    output, process = Open3.capture2e(environment, 'sh', '-c', step.last)
    assert_predicate process, :success?, output
    assert_equal 'A5', status(root)['state']
  end

  def test_status_reads_a_named_directory
    run_install(@root, '--directory', @root, '--repository', @remote, '--agent', 'claude')
    File.unlink(File.join(@home, '.claude/skills/shaka'))
    second = clone_to(File.join(@directory, 'second clone'))
    output, process = run_status(second, '--json', '--directory', @root)
    assert_predicate process, :success?, output
    assert_equal 'B9', JSON.parse(output)['state']
  end

  def test_an_unsafe_path_containing_is_names_the_whole_directory
    root = clone_to(File.join(@directory, 'what is this', 'shaka'))
    run_install(root, '--directory', root, '--repository', @remote)
    File.chmod(0o775, root)
    report = status(root)
    assert_equal "chmod go-w #{Shellwords.escape(File.realpath(root))}", report['next_command']
  end

  def test_a_managed_copy_in_a_custom_folder_is_recognized
    copies = File.join(@directory, 'copies')
    output, process = Open3.capture2e(environment, RbConfig.ruby, @installer, '--skills-dir',
                                      File.join(@home, '.claude/skills'), '--managed-dir', copies)
    assert_predicate process, :success?, output
    assert_equal 'A7', status(@root)['state']
  end

  def test_a_branch_without_its_upstream_is_named
    root = default_install
    git('-C', root, 'branch', '-q', '--unset-upstream')
    report = status(root)
    assert_equal 'B4', report['state']
    assert_includes report['next_command'], 'branch --set-upstream-to origin/main'
  end

  def test_a_record_whose_links_were_all_removed_is_an_orphan
    orphan = default_install
    File.unlink(File.join(@home, '.agents/skills/shaka'))
    run_install(@root, '--directory', @root, '--repository', @remote, '--agent', 'claude')
    report = status(@root)
    assert_equal 'C1', report['state']
    assert_equal File.realpath(orphan), report['location']
  end

  def test_an_unreadable_record_asks_a_person
    root = default_install
    File.write(File.join(root, '.git/shaka-install.json'), '{')
    report = status(root)
    assert_equal 'C1', report['state']
    assert_nil report['next_command']
    assert_includes report['decision'], 'rename it aside'
  end

  private

  def pulled_without_ruby
    root = clone_to(File.join(@home, '.agents/shaka'))
    run_install(root, '--repository', @remote)
    pull(root)
    File.write(File.join(root, '.git/shaka-ruby'), "/nonexistent/ruby\n")
    root
  end
end
