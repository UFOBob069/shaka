# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'tmpdir'
require 'yaml'
require 'shaka/local_review'
require 'shaka/local_review/loop_comment'
require 'shaka/evidence/result'
require 'shaka/doctor/installation_identity'

# A trusted commit and a change, reviewed by a fake Codex through `review run --ledger --settings-ref`.
module LocalReviewSettingsRereviewFixture
  REPOSITORY = 'owner/repo'

  private

  def in_repository(&)
    Dir.mktmpdir('shaka-rereview') do |directory|
      @root = File.join(directory, 'checkout')
      @bin = File.join(directory, 'bin')
      @ledger = File.join(directory, 'ledger.json')
      Dir.mkdir(@root)
      Dir.mkdir(@bin)
      create_repository
      fake_codex
      with_path(&)
    end
  end

  def create_repository
    git('init', '-q', '-b', 'main')
    FileUtils.mkdir_p(File.join(@root, '.agents/bin'))
    %w[setup validate test].each { |name| executable(File.join(@root, '.agents/bin', name), "#!/bin/sh\n") }
    File.write(File.join(@root, '.agents/agent-workflow.yml'),
               YAML.dump('version' => 1, 'merge' => { 'preference' => 'ask' }, 'review' => { 'required' => 'none' }))
    @base = commit('trusted')
    File.write(File.join(@root, 'example.txt'), "change\n")
    @head = commit('change')
  end

  def fake_codex(findings: 0)
    executable(File.join(@bin, 'codex'), <<~RUBY)
      #!/usr/bin/env ruby
      File.write(#{File.join(@bin, 'prompt').inspect}, STDIN.read)
      File.write(ARGV.fetch(ARGV.index('-o') + 1), "report\\nREVIEWED #{@head} BY openai/codex EFFORT medium FINDINGS #{findings}\\n")
    RUBY
  end

  def with_path
    original = ENV.fetch('PATH')
    ENV['PATH'] = "#{@bin}:#{original}"
    yield
  ensure
    ENV['PATH'] = original
  end

  def review(expect: 0)
    output, = capture_io do
      assert_equal expect, Shaka::LocalReview.run(
        ['run', '--root', @root, '--base', @base, '--head', @head, '--reviewer', 'openai/codex',
         '--effort', 'medium', '--settings-ref', @base, '--repository', REPOSITORY, '--ledger', @ledger]
      )
    end
    JSON.parse(output)
  end

  def record_clean(findings = [])
    path = "#{@ledger}.record.json"
    File.write(path, JSON.generate('findings' => findings))
    capture_io { assert_equal 0, Shaka::LocalReview.run(['record', '--ledger', @ledger, '--content-file', path]) }
  end

  # The installed checkout moved to another version while the task kept running.
  def updated_installation
    identity = Shaka::Doctor::InstallationIdentity
    original = identity.method(:read)
    updated = original.call.merge('version' => "#{original.call['version']}.next")
    identity.define_singleton_method(:read) { updated }
    yield
  ensure
    identity.define_singleton_method(:read, original)
  end

  def bind(result)
    Shaka::Evidence::Result.bind(result, root: @root, ref: @base, head: @head, repository: REPOSITORY)
  end

  def ledger_rounds = JSON.parse(File.read(@ledger)).fetch('rounds')

  def commit(message)
    git('add', '-A')
    git('-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-q', '-m', message)
    git('rev-parse', 'HEAD')
  end

  def git(*)
    output, error, status = Open3.capture3(TEST_GIT, '-C', @root, *)
    assert_predicate status, :success?, error
    output.strip
  end

  def executable(path, source)
    File.write(path, source)
    File.chmod(0o755, path)
  end

  def published
    Shaka::LocalReviewLoopComment.new(JSON.parse(File.read(@ledger)), subject: ->(_) { 'Subject' }).render
  end
end

# Break caught: an installation update mid-task superseded every review of the unchanged head, and
# the ledger then refused the only way to produce current evidence: another review of that head.
class LocalReviewSettingsRereviewTest < Minitest::Test
  include LocalReviewSettingsRereviewFixture

  def test_a_changed_installation_permits_a_review_of_the_same_head
    in_repository do
      first = review
      record_clean
      updated_installation do
        assert_includes bind(first).fetch('reasons'), 'settings components differ: installation'
        second = review
        assert_equal 'bound', bind(second).fetch('status')
        assert_equal [2, 2], [second.fetch('round'), ledger_rounds.size]
      end
    end
  end

  def test_unchanged_settings_still_refuse_a_review_of_the_same_head
    in_repository do
      review
      record_clean
      assert_includes review(expect: 1).fetch('reason'), 'Round 1 already reviewed'
      updated_installation do
        review
        record_clean
        assert_includes review(expect: 1).fetch('reason'), 'Round 2 already reviewed'
      end
    end
  end

  def test_a_settings_rereview_waits_for_the_earlier_findings_to_be_recorded
    in_repository do
      fake_codex(findings: 1)
      review
      updated_installation { assert_includes review(expect: 1).fetch('reason'), 'Record round 1' }
    end
  end

  # Break caught: with no earlier commit, the re-review prompt left out every earlier finding.
  def test_a_settings_rereview_of_the_first_commit_sees_earlier_findings
    in_repository do
      fake_codex(findings: 1)
      review
      record_clean([{ 'id' => 'F1', 'summary' => 'Missing test', 'class' => 'nit', 'disposition' => 'documented' }])
      fake_codex
      updated_installation { review }
      assert_includes File.read(File.join(@bin, 'prompt')), '- [F1] nit: Missing test'
    end
  end

  def test_the_published_comment_labels_the_settings_rereview_beside_the_earlier_round
    in_repository do
      review
      record_clean
      updated_installation { review }
      record_clean
      body = published
      assert_includes body, "Round 1 · #{@head[0, 7]} · openai/codex · effort"
      assert_includes body, "Round 2 · #{@head[0, 7]} · openai/codex · settings re-review · effort"
      refute_includes body, ledger_rounds.last.fetch('settings')
    end
  end
end
