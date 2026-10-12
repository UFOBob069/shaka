# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'repository_fixture'
require 'json'

module FinalPreparationFixture
  include RepositoryConfigTestHelpers

  HEAD = 'a' * 40
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  FAKE_GH = <<~'RUBY'
    #!/usr/bin/env ruby
    require 'json'
    data = JSON.parse(File.read(ENV.fetch('FINAL_FIXTURE')))
    path = ARGV[1]
    fields = JSON.parse($stdin.read)
    case path
    when 'user' then puts JSON.generate('login' => 'agent')
    when /issues\/1\/comments/
      if ARGV.include?('POST')
        File.write(ENV.fetch('FINAL_WRITTEN'), fields.fetch('body'))
        puts JSON.generate('id' => 10, 'html_url' => 'https://example.test/c/10', 'body' => fields['body'])
      else
        puts JSON.generate(data.fetch('comments'))
      end
    when /pulls\/1\/commits/
      puts JSON.generate([{ 'commit' => { 'message' => 'Fix' } }])
    when 'graphql'
      puts JSON.generate('data' => { 'repository' => { 'pullRequest' => {
        'state' => 'OPEN', 'headRefOid' => 'a' * 40, 'commits' => { 'totalCount' => 1 }
      } } })
    else
      warn "unexpected gh #{ARGV.inspect}"
      exit 2
    end
  RUBY

  private

  def with_fixture(enabled: true)
    with_repository('review' => review_policy('post_implementation' => { 'enabled' => enabled })) do |root|
      commit_root(root)
      ref = Open3.capture2('git', '-C', root, 'rev-parse', 'HEAD').first.strip
      Dir.mktmpdir do |bin|
        prepare_bin(bin)
        yield root, ref, bin
      end
    end
  end

  def commit_root(root)
    system('git', '-C', root, 'init', '--quiet', exception: true)
    system('git', '-C', root, 'add', '.', exception: true)
    system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.test',
           'commit', '--quiet', '-m', 'trusted', exception: true)
  end

  def prepare_bin(bin)
    File.write(File.join(bin, 'gh'), FAKE_GH)
    File.chmod(0o755, File.join(bin, 'gh'))
    File.write(File.join(bin, 'fixture'), JSON.generate('comments' => []))
    File.write(File.join(bin, 'message'), JSON.generate('title' => 'Fix', 'body' => 'Reason.'))
  end

  def change_candidate(root, enabled:)
    File.write(File.join(root, '.agents/agent-workflow.yml'),
               YAML.dump(seam('review' => review_policy('post_implementation' => { 'enabled' => enabled }))))
  end

  def write_comments(bin, head)
    comment = { 'id' => 1, 'user' => { 'login' => 'agent' },
                'body' => "<!-- shaka:reply:post-implementation-#{head[0, 7]}-abc12345 -->\nReport\n\n" \
                          "<!-- shaka:post-implementation #{head} ready -->" }
    File.write(File.join(bin, 'fixture'), JSON.generate('comments' => [comment]))
  end

  def run_command(root, ref, bin, command)
    flag = command == 'merge' ? '--squash-message' : '--content-file'
    env = { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'FINAL_FIXTURE' => File.join(bin, 'fixture'),
            'FINAL_WRITTEN' => File.join(bin, 'written') }
    Open3.capture3(env, COMMAND, command, 'owner/repo', '1', '--root', root, '--ref', ref, '--head', HEAD,
                   flag, File.join(bin, 'message'), '--base', 'main', '--walkthrough', '1')
  end
end

class CliFinalPreparationTest < Minitest::Test
  include FinalPreparationFixture

  def test_final_commands_refuse_missing_reviews_before_any_write
    with_fixture do |root, ref, bin|
      %w[squash-message merge].each do |command|
        _output, error, status = run_command(root, ref, bin, command)
        refute_predicate status, :success?
        assert_includes error, 'Checkpoint is missing'
        refute_path_exists File.join(bin, 'written')
      end
    end
  end

  def test_current_review_allows_message_publication
    with_fixture do |root, ref, bin|
      write_comments(bin, HEAD)
      _output, error, status = run_command(root, ref, bin, 'squash-message')
      assert_predicate status, :success?, error
      assert_includes File.read(File.join(bin, 'written')), 'Reason.'
    end
  end

  def test_stale_review_blocks_message_publication
    with_fixture do |root, ref, bin|
      write_comments(bin, 'b' * 40)
      _output, error, status = run_command(root, ref, bin, 'squash-message')
      refute_predicate status, :success?
      assert_includes error, 'Checkpoint is missing'
      refute_path_exists File.join(bin, 'written')
    end
  end

  def test_only_the_trusted_disabled_setting_can_skip_the_checkpoint
    [true, false].each do |enabled|
      with_fixture(enabled:) do |root, ref, bin|
        change_candidate(root, enabled: !enabled)
        _output, error, status = run_command(root, ref, bin, 'squash-message')
        assert_equal !enabled, status.success?, error
        assert_equal !enabled, File.exist?(File.join(bin, 'written'))
      end
    end
  end

  def test_squash_message_requires_a_trusted_ref
    _output, error, status = Open3.capture3(COMMAND, 'squash-message', 'owner/repo', '1', '--head', HEAD)
    refute_predicate status, :success?
    assert_includes error, 'squash-message requires --ref'
  end
end
