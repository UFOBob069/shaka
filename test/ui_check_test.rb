# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'shaka/ui_check'

module UiCheckFixture
  HEAD = 'a' * 40
  OLD = 'b' * 40
  IDENTITY = { 'agent' => 'Claude Code', 'provider' => 'Anthropic', 'model' => 'observed-model', 'effort' => 'high' }
             .freeze
  BYLINE = "🤖 Claude Code · Anthropic · observed-model · high\n\n"

  def asset(name) = "https://github.com/user-attachments/assets/#{name}"

  # Stands in for GitHub and gh: posting rewrites referenced files to uploads and appends the rest.
  class GitHub < Shaka::GitHub
    attr_reader :comments, :posts
    attr_accessor :head, :upload

    def initialize(comments)
      super('example/test', '1')
      @comments = comments
      @posts = []
      @head = HEAD
      @upload = true
    end

    def snapshot = { 'state' => 'OPEN', 'headRefOid' => head }
    def viewer_login = 'ada'
    def issue_comments = comments.map(&:dup)
    def verify_rendering(_body) = '<details><p>Rendered.</p></details>'

    def post_comment(body, attachments: [])
      @posts << body
      attachments.each_with_index { |attachment, index| body = attach(body, attachment.split('#', 2).first, index) }
      comments << UiCheckFixture.row(comments.map { |comment| comment['id'] }.max.to_i + 1, body)
    end

    def attach(body, path, index)
      url = upload ? "https://github.com/user-attachments/assets/new-#{index}" : path
      body.include?("](#{path})") ? body.gsub("](#{path})", "](#{url})") : "#{body}\n![](#{url})\n"
    end

    def api(path, method: 'GET', fields: {})
      row = comments.find { |comment| comment['id'] == path.split('/').last.to_i } || raise(Shaka::Error, 'Not Found')
      row['body'] = fields.fetch(:body) if method == 'PATCH'
      row.dup
    end
  end

  def self.row(id, body, login: 'ada')
    { 'id' => id, 'created_at' => format('2026-10-11T00:00:%02dZ', id), 'user' => { 'login' => login },
      'issue_url' => 'https://api.github.com/repos/example/test/issues/1', 'body' => body,
      'html_url' => "https://github.com/example/test/pull/1#issuecomment-#{id}" }
  end

  def earlier_check(id, *assets, login: 'ada')
    images = assets.map { |name| "![View](#{asset(name)})" }.join("\n")
    marker = "<!-- shaka:ui-check-#{OLD}-0000000#{id} -->"
    UiCheckFixture.row(id, "#{BYLINE}#{marker}\n# Verification\n\n#{images}\n", login:)
  end

  # Optional content keys (captures, retire, earlier) pass through as given.
  def publish(github, body:, nonce: 'feedf00d', **optional)
    content = { 'identity' => IDENTITY, 'body' => body }.merge(optional.transform_keys(&:to_s))
    Shaka::UiCheck::Publisher.new(github, nonce:).call(head: HEAD, content:)
  end

  def legacy_check(id, name, login: 'ada')
    UiCheckFixture.row(id, "#{BYLINE}**UI check at bbbbbbb**\n\n![View](#{asset(name)})\n", login:)
  end

  def with_capture
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'after.png')
      File.write(path, 'png')
      yield path
    end
  end
end

class UiCheckPublisherTest < Minitest::Test
  include UiCheckFixture

  def assert_posted(body)
    assert body.start_with?("#{BYLINE}<!-- shaka:ui-check-#{HEAD}-feedf00d -->\n# Verification for [`aaaaaaa`]")
    assert_includes body, asset('new-0')
  end

  def test_new_check_carries_its_marker_heading_and_upload_then_folds_earlier_own_checks
    github = GitHub.new([earlier_check(1, 'home')])
    with_capture do |path|
      result = publish(github, body: "Home unchanged: ![Home](#{asset('home')})\n\n![After](#{path})",
                               captures: ["#{path}#After"])

      assert_posted(github.comments.last['body'])
      assert_equal [1], result['collapsed']
      assert_includes github.comments.first['body'], Shaka::EvidenceHistory::MARKER
    end
  end

  def test_a_capture_left_out_of_the_new_check_refuses_before_posting
    github = GitHub.new([earlier_check(1, 'home', 'examples')])
    error = assert_raises(Shaka::Error) { publish(github, body: "![Home](#{asset('home')})") }

    assert_includes error.message, asset('examples')
    assert_empty github.posts
  end

  def test_a_retired_capture_may_be_left_out
    github = GitHub.new([earlier_check(1, 'home', 'examples')])
    result = publish(github, body: "![Home](#{asset('home')})", retire: [asset('examples')])

    assert_equal [1], result['collapsed']
  end

  def test_retiring_a_capture_no_open_check_shows_refuses
    github = GitHub.new([earlier_check(1, 'home')])
    error = assert_raises(Shaka::Error) do
      publish(github, body: "![Home](#{asset('home')})", retire: [asset('typo')])
    end

    assert_includes error.message, asset('typo')
    assert_empty github.posts
  end

  def test_folded_checks_and_other_writers_checks_are_neither_required_nor_folded
    other = earlier_check(2, 'people', login: 'someone-else')
    github = GitHub.new([earlier_check(1, 'home'), other.dup])
    publish(github, body: "![Home](#{asset('home')})")
    result = publish(github, body: 'Every view is new.', retire: [asset('home')], nonce: '0badcafe')

    assert_equal [3], result['collapsed']
    assert_equal other, github.comments[1]
  end

  def test_a_named_check_posted_before_the_command_must_be_carried_and_is_folded
    github = GitHub.new([legacy_check(1, 'examples')])
    assert_raises(Shaka::Error) { publish(github, body: 'Homepage only.', earlier: [1]) }

    result = publish(github, body: "Examples unchanged: ![Examples](#{asset('examples')})", earlier: [1])
    assert_equal [1], result['collapsed']
  end

  def test_naming_another_writers_comment_refuses_before_posting
    github = GitHub.new([legacy_check(1, 'examples', login: 'someone-else')])
    error = assert_raises(Shaka::Error) { publish(github, body: 'Checked.', earlier: [1]) }

    assert_includes error.message, 'not this account'
    assert_empty github.posts
  end

  def test_a_moved_head_or_unreadable_capture_refuses_before_posting
    github = GitHub.new([])
    github.head = OLD
    assert_raises(Shaka::Error) { publish(github, body: 'Checked.') }
    github.head = HEAD
    assert_raises(Shaka::Error) { publish(github, body: 'Checked.', captures: ['/missing/after.png#After']) }
    assert_empty github.posts
  end

  def test_a_capture_that_did_not_upload_is_reported_and_nothing_is_folded
    github = GitHub.new([earlier_check(1, 'home')])
    github.upload = false
    with_capture do |path|
      error = assert_raises(Shaka::Error) do
        publish(github, body: "![Home](#{asset('home')})\n\n![After](#{path})", captures: ["#{path}#After"])
      end

      assert_includes error.message, 'missing uploaded captures'
      refute_includes github.comments.first['body'], Shaka::EvidenceHistory::MARKER
    end
  end
end

class UiCheckCommandTest < Minitest::Test
  def test_missing_head_or_content_is_a_usage_error
    _out, err = capture_io { assert_equal 1, Shaka::UiCheck.run(['example/test', '1', '--content-file', 'x.json']) }
    assert_includes err, 'missing argument: --head'

    _out, err = capture_io { assert_equal 1, Shaka::UiCheck.run(['example/test', '1', '--head', 'a' * 40]) }
    assert_includes err, 'Usage: shaka ui-check'
  end
end

class UiCheckPostCommentTest < Minitest::Test
  def test_gh_receives_the_body_on_stdin_and_each_capture_as_an_attachment
    calls = []
    runner = lambda do |argv, stdin_data:|
      calls << [argv, stdin_data]
      ['https://github.com/example/test/pull/1#issuecomment-9', '', Struct.new(:exitstatus).new(0)]
    end
    Shaka::GitHub.new('example/test', '1', runner:).post_comment('Checked.', attachments: ['a.png#After'])

    assert_equal [%w[gh pr comment 1 --repo example/test --body-file - --attach a.png#After], 'Checked.'], calls.first
  end
end
