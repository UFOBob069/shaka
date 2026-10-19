# frozen_string_literal: true

require_relative 'install_refusal_support'

# A checkout refusal names the checkout and what differs, and its next command clears it.
class OfficialInstallRefusalTest < Minitest::Test
  include InstallRefusalSupport

  def test_dirty_checkout_lists_at_most_five_paths_and_stash_clears_it
    official_install
    7.times { |index| File.write(File.join(@root, "personal-#{index}.txt"), 'keep me') }
    output = refusal('--update', 'Installation checkout has uncommitted changes', checkout)
    assert_includes output, 'personal-0.txt'
    assert_includes output, 'and 2 more'
    run_next(output)
    assert_succeeds('--update')
  end

  def test_switched_branch_names_both_branches_and_switch_clears_it
    official_install
    git('-C', @root, 'switch', '-qc', 'development')
    output = refusal('--update', 'is on branch development; expected main', checkout)
    run_next(output)
    assert_succeeds('--update')
  end

  def test_detached_checkout_names_its_revision
    official_install
    git('-C', @root, 'switch', '-q', '--detach')
    output = refusal('--update', "a detached HEAD at #{git('-C', @root, 'rev-parse', '--short=7', 'HEAD').strip}")
    run_next(output)
    assert_succeeds('--update')
  end

  def test_untracked_branch_names_what_it_follows_and_branch_u_clears_it
    official_install
    git('-C', @root, 'branch', '--unset-upstream')
    output = refusal('--update', 'Installation branch main does not follow origin/main', 'follows no remote branch')
    run_next(output)
    assert_succeeds('--update')
  end

  def test_changed_origin_names_both_urls_and_set_url_clears_it
    official_install
    git('-C', @root, 'remote', 'set-url', 'origin', 'https://example.com/other.git')
    output = refusal('--update', 'has origin https://example.com/other.git', "expected #{@remote}",
                     'a person must decide which repository this installation follows')
    run_next(output)
    assert_succeeds('--update')
  end

  def test_origin_credentials_never_appear_in_the_refusal
    official_install
    git('-C', @root, 'remote', 'set-url', 'origin', 'https://user:secret@token@example.com/other.git')
    output = refusal('--update', 'has origin https://CREDENTIALS@example.com/other.git')
    refute_includes output, 'secret'
    refute_includes output, 'token@'
  end

  def test_rewritten_origin_says_the_installation_is_unchanged
    official_install
    before = git('-C', @root, 'rev-parse', 'HEAD').strip
    rewrite_origin
    output = refusal('--update', "The registered branch (origin/main of #{@remote}) was rewritten",
                     "stays at #{before[0, 7]}, unchanged", 'a person must decide whether to trust the new history')
    assert_equal before, git('-C', @root, 'rev-parse', 'HEAD').strip
    refute JSON.parse(File.read(File.join(@root, '.git/shaka-install.json'))).key?('pending_revision')
    _, status = run_next(output)
    assert_predicate status, :success?
  end

  private

  def rewrite_origin
    clone = File.join(@directory, 'rewrite')
    git('clone', '-q', '-b', 'main', @remote, clone)
    git('-C', clone, '-c', 'user.name=T', '-c', 'user.email=t@x', 'commit', '--amend', '-qm', 'rewritten')
    git('-C', clone, 'push', '--force', '-q', 'origin', 'main')
  end
end
