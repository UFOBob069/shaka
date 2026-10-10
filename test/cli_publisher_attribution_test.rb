# frozen_string_literal: true

require_relative 'publisher_attribution_test'
require_relative 'claude_publisher_attribution_test'
require_relative 'cli_opening_check_fakes'

class CliPublisherAttributionTest < Minitest::Test
  include PublisherAttributionFixture
  include ClaudePublisherAttributionFixture
  include CliOpeningCheckFakes

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  ROOT = File.expand_path('..', __dir__)
  SUMMARY = 'Missing attribution comes from the publisher session.'

  REPLY_GH_CASES = <<~CODE
    when 'user' then puts JSON.generate('login' => 'author')
    when %r{repos/owner/repo/issues/1/comments}
      if ARGV.include?('POST')
        File.write(File.join(ENV.fetch('HOME'), 'published.md'), request.fetch('body'))
        puts JSON.generate(request)
      else
        puts '[]'
      end
  CODE

  def test_description_publishes_native_header_and_provenance
    with_session(context) do |environment, _file|
      run_publication(environment) do |dir, output, error, status|
        assert_predicate status, :success?, "#{output}\n#{error}"
        body = File.read(File.join(dir, 'published.md'))
        assert_includes body, 'Codex · OpenAI · gpt-6.1-sol (configured) · medium'
        assert_includes body, '| Active model / effort | gpt-6.1-sol / medium |'
      end
    end
  end

  def test_claude_code_description_publishes_session_settings_without_a_note
    with_claude_session(prompt, response) do |environment, _file|
      @identity = claude_content.fetch('identity')
      run_publication(environment) do |dir, output, error, status|
        assert_predicate status, :success?, "#{output}\n#{error}"
        body = File.read(File.join(dir, 'published.md'))
        assert_includes body, "🤖 Claude Code · Anthropic · claude-opus-5-5 · medium\n\n#{SUMMARY}"
        assert_includes body, '| Active model / effort | claude-opus-5-5 / medium |'
      end
    end
  end

  def test_conflicting_identity_does_not_write_to_github
    with_session(context) do |environment, _file|
      @conflict = true
      run_publication(environment) do |dir, _output, error, status|
        refute_predicate status, :success?
        assert_includes error, 'conflicts with native publisher settings'
        refute_path_exists File.join(dir, 'published.md')
      end
    end
  end

  def test_reply_publishes_native_identity_and_generated_note
    with_session(context) do |environment, _file|
      run_publication(environment, command: 'reply') do |dir, _output, error, status|
        assert_predicate status, :success?, error
        body = File.read(File.join(dir, 'published.md'))
        assert_includes body, 'Codex · OpenAI · gpt-6.1-sol (configured) · medium'
        assert_includes body, 'served model is UNKNOWN'
      end
    end
  end

  private

  def description_content
    super.tap do |supplied|
      supplied['identity'] = @identity if @identity
      supplied['identity']['model'] = 'other-model' if @conflict
    end
  end

  def run_publication(environment, command: 'description')
    Dir.mktmpdir do |dir|
      write_fake_commands(dir)
      file = File.join(dir, 'content.json')
      supplied = description_content
      supplied = supplied.slice('identity', 'summary') if command == 'reply'
      File.write(file, JSON.generate(supplied))
      env = command_environment(environment, dir)
      result = invoke(env, file, command)
      yield dir, *result
    end
  end

  def invoke(env, file, command)
    flags = command == 'reply' ? ['--key', 'native-attribution'] : ['--root', ROOT]
    Open3.capture3(env, COMMAND, command, 'owner/repo', '1', '--content-file', file, *flags)
  end

  def fake_gh
    super.sub('else abort', "#{REPLY_GH_CASES}else abort")
  end

  def command_environment(environment, dir)
    hosts = Shaka::PublisherAttribution::HOST_VARIABLES.to_h { |variable| [variable, nil] }
    hosts.merge(environment, 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir)
  end
end
