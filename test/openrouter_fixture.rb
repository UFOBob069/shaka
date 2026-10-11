# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tempfile'
require 'shaka/local_review/cli'

# Fixtures replace the fixed API transport; tests never send paid requests.
module OpenrouterFixture
  MODEL = 'deepseek/deepseek-v4.1-flash'
  HEAD = 'a' * 40

  private

  def completion(head = HEAD)
    { 'id' => 'gen-test', 'model' => MODEL, 'created' => 1_791_343_000,
      'choices' => [{ 'finish_reason' => 'stop', 'message' => {
        'content' => "No findings.\nREVIEWED #{head} BY deepseek/openrouter EFFORT high FINDINGS 0"
      } }],
      'usage' => { 'prompt_tokens' => 100, 'completion_tokens' => 20, 'total_tokens' => 120,
                   'cost' => 0.0024, 'prompt_tokens_details' => { 'cached_tokens' => 40 },
                   'completion_tokens_details' => { 'reasoning_tokens' => 5 } } }
  end

  def replacing_method(object, name, replacement)
    original = object.method(name)
    object.define_singleton_method(name) { |*args, **options, &block| replacement.call(*args, **options, &block) }
    yield
  ensure
    object.define_singleton_method(name, original)
  end

  def with_request(replacement, &)
    replacing_method(Shaka::OpenrouterReview, :request, replacement, &)
  end

  def with_key(value = 'fixture-only')
    original = ENV.fetch('OPENROUTER_API_KEY', nil)
    ENV['OPENROUTER_API_KEY'] = value
    yield
  ensure
    ENV['OPENROUTER_API_KEY'] = original
  end

  def with_adapter(**overrides)
    options = { reviewer: 'deepseek/openrouter', model: MODEL, effort: 'high', head: HEAD,
                timeout_seconds: 1 }.merge(overrides)
    with_key do
      Tempfile.create('openrouter-report') { |report| yield adapter(options, report.path), options, report.path }
    ensure
      File.unlink(options[:usage]) if options[:usage] && File.exist?(options[:usage])
    end
  end

  def adapter(options, report)
    Shaka::LocalReviewCli.new(options, root: Dir.tmpdir, report:, candidate_root: Dir.pwd)
  end

  def with_review_repository
    Dir.mktmpdir('openrouter-review') do |root|
      git!(root, 'init', '-q')
      File.write(File.join(root, 'code.rb'), "puts :before\n")
      base = commit(root)
      File.write(File.join(root, 'code.rb'), "puts :after\n")
      yield root, base, commit(root)
    end
  end

  def commit(root)
    git!(root, 'add', '.')
    git!(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-qm', 'fixture')
    git!(root, 'rev-parse', 'HEAD').strip
  end

  def git!(root, *)
    output, status = Open3.capture2e(TEST_GIT, '-C', root, *)
    raise output unless status.success?

    output
  end
end
