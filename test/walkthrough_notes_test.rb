# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/walkthrough/notes'
require 'shaka/publication/human_comment_entries'
require 'json'
require 'open3'
require 'tmpdir'

class WalkthroughNotesTest < Minitest::Test
  HEAD = 'a' * 40
  PACKAGE = <<~RUBY
    class Package
      def prepare(root)
        stage(root)
      end

      def stage(root)
        copy(root)
        publish(root)
      end

      def publish(root)
        rename(root)
      end
    end
  RUBY

  # Serves lib/package.rb from the contents API, as a code link reads it.
  FakeGitHub = Struct.new(:repository) do
    def api(path, **)
      raise Shaka::Error, "gh api #{path} failed (exit 1)." unless path.include?('/contents/lib/package.rb?')

      { 'type' => 'file', 'encoding' => 'base64', 'content' => [PACKAGE].pack('m') }
    end

    def api_list(_path) = [{ 'name' => 'package.rb', 'type' => 'file' }]
  end

  def github = FakeGitHub.new('owner/repo')

  IDENTITY = { 'agent' => 'claude', 'provider' => 'anthropic', 'model' => 'model', 'effort' => 'high' }.freeze

  def notes(*items)
    Shaka::Walkthrough::Notes.resolve({ 'head' => HEAD, 'identity' => IDENTITY, 'notes' => items }, github)
  end

  def test_a_note_on_one_line_anchors_that_line_on_the_new_side
    note = notes({ 'path' => 'lib/package.rb', 'from' => 'def publish', 'body' => 'Start here.' }).first
    assert_equal({ 'path' => 'lib/package.rb', 'line' => 11, 'side' => 'RIGHT' }, note.except('body'))
    assert_equal "#{Shaka::Walkthrough::Notes::MARKER}\n🤖 Claude · Anthropic · model · high\n\nStart here.",
                 note['body']
  end

  def test_a_block_note_spans_its_first_and_last_lines
    note = notes({ 'path' => 'lib/package.rb', 'from' => 'def stage', 'block' => true, 'body' => 'Core change.' })
    assert_equal({ 'path' => 'lib/package.rb', 'start_line' => 6, 'start_side' => 'RIGHT', 'line' => 9,
                   'side' => 'RIGHT' }, note.first.except('body'))
    assert_equal 'lib/package.rb:L6-L9', Shaka::Walkthrough::Notes.location(note.first)
  end

  def test_a_walkthrough_without_notes_has_none
    assert_empty Shaka::Walkthrough::Notes.resolve({ 'head' => HEAD }, github)
  end

  MALFORMED = { 'must be a list' => 'Start here.',
                'note 1 must be an object' => ['Start here.'],
                'note 1 has unknown key line' => [{ 'path' => 'lib/package.rb', 'line' => 3, 'body' => 'x' }],
                'walkthrough note 1 must be nonempty' => [{ 'path' => 'lib/package.rb', 'from' => 'def stage' }],
                'note 2: "def missing" matches 0 lines' =>
                  [{ 'path' => 'lib/package.rb', 'from' => 'def stage', 'body' => 'x' },
                   { 'path' => 'lib/package.rb', 'from' => 'def missing', 'body' => 'x' }] }.freeze

  def test_malformed_notes_are_refused_with_their_number
    MALFORMED.each do |message, items|
      content = { 'head' => HEAD, 'identity' => IDENTITY, 'notes' => items }
      error = assert_raises(Shaka::Error) { Shaka::Walkthrough::Notes.resolve(content, github) }
      assert_includes error.message, message
    end
  end

  # The comment reader leaves agent posts out of the Human comments list by their opening.
  def test_a_note_opens_as_an_agent_post
    body = notes({ 'path' => 'lib/package.rb', 'from' => 'def publish', 'body' => 'Skim this.' }).first['body']
    assert_match Shaka::HumanCommentEntries::AGENT_OPENING, body
  end
end

class WalkthroughNotesCommandTest < Minitest::Test
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)

  # The command hands walkthrough notes to Notes, which refuses a malformed list before GitHub.
  # A stub gh on PATH records any invocation.
  def test_notes_reach_the_note_check_before_any_github_call
    Dir.mktmpdir do |dir|
      sentinel = File.join(dir, 'called')
      File.write(File.join(dir, 'gh'), "#!/bin/sh\ntouch #{sentinel}\nexit 1\n")
      File.chmod(0o755, File.join(dir, 'gh'))
      _output, error, status = publish_notes(dir, 'Start here.')
      refute_predicate status, :success?
      assert_includes error, 'Walkthrough notes must be a list.'
      refute_path_exists sentinel
    end
  end

  def publish_notes(dir, notes)
    identity = { 'agent' => 'claude', 'provider' => 'anthropic', 'model' => 'UNKNOWN', 'effort' => 'UNKNOWN' }
    path = File.join(dir, 'content.json')
    File.write(path, JSON.generate({ 'identity' => identity, 'summary' => 'Done.', 'notes' => notes }))
    Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}" }, COMMAND, 'walkthrough', 'owner/repo', '1',
                   '--head', 'a' * 40, '--content-file', path)
  end
end
