# frozen_string_literal: true

require_relative 'private_setup_test'
require_relative 'evidence_fixture'
require_relative 'cli_opening_check_fakes'
require_relative 'handoff_helper'

module PrivateTrialPublicationHelpers
  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  SECRET = 'synthetic-credential-277'
  PRIVATE_LINK = 'https://private.example/prompt?token=synthetic-credential-277'
  CHECKOUT = '/synthetic/approved-checkout'
  SESSION = 'codex://threads/00000000-0000-4000-8000-000000000277'

  def fresh_trial(root, ref)
    selected = options.merge(validate_command: "bin/probe --credential=#{SECRET}")
    Shaka::Seam::PrivateSetup.new(root:, ref:, options: selected).setup
    File.write(File.join(root, '.agents/shaka/private-prompt.md'), PRIVATE_LINK)
    before = File.read(config_path(root))
    File.write(File.join(root, 'README.md'), "public feature\n")
    commit_file(root, 'README.md', 'feature')
    @head = head(root)
    before
  end

  def verify_publication(root, ref, validation, review)
    Dir.mktmpdir do |dir|
      body = publish_trial(dir, root, ref, validation, review)
      assert_public_settings(body, ref)
      assert_public_handoff(body)
      refute_private_values(body, root, validation, review)
    end
  end

  def refute_private_values(body, root, validation, review)
    [SECRET, PRIVATE_LINK, root, validation.dig('settings', 'digest'),
     review.dig('settings', 'digest'), Digest::SHA256.hexdigest(PRIVATE_LINK)].each do |private_value|
      refute_includes body, private_value
    end
  end

  def assert_unfinished_private(body, root)
    assert_includes body, 'UNKNOWN: rerun missing evidence'
    assert_includes body, '| wip.include_locations | true |'
    assert_includes body, "| Workspace | #{CHECKOUT} |"
    assert_includes body, "| Chat link | #{SESSION} |"
    refute_includes body, PRIVATE_LINK
    refute_includes body, root
  end

  def review_for(root, ref)
    Tempfile.create(['trial-review-', '.md']) do |report|
      report.write("Findings: none\nREVIEWED #{@head} BY openai/codex EFFORT medium FINDINGS 0\n")
      report.flush
      output, = capture_io do
        args = review_arguments(root, ref, report.path)
        args[args.index('--head') + 1] = @head
        assert_equal 0, Shaka::LocalReview.run(args)
      end
      JSON.parse(output)
    end
  end

  def publish_trial(dir, root, ref, validation = nil, review = nil)
    write_fake_commands(dir)
    path = trial_content(dir)
    flags = result_flags(dir, validation, review)
    _output, error, status = Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir }, COMMAND,
                                            'description', 'shakacode/shaka', '1', '--root', root, '--ref', ref,
                                            '--content-file', path, *flags)
    assert_predicate status, :success?, error
    File.read(File.join(dir, 'published.md'))
  end

  def trial_content(dir)
    supplied = description_content.merge('wip' => HandoffFixtures::WIP.merge(
      'revision' => "feature @ #{@head}", 'workspace' => CHECKOUT, 'thread' => SESSION
    ))
    path = File.join(dir, 'content.json')
    File.write(path, JSON.generate(supplied))
    path
  end

  def result_flags(dir, validation, review)
    { 'validation' => validation, 'review' => review }.compact.flat_map do |kind, result|
      result_path = File.join(dir, "#{kind}.json")
      File.write(result_path, JSON.generate(result))
      ["--#{kind}-result", result_path]
    end
  end

  def fake_gh
    source = super.gsub('owner/repo', 'shakacode/shaka').gsub("'c' * 40", @head.dump)
    source = source.sub("'changed_files' => 0", "'changed_files' => 1")
    source.sub("then puts '[]'", "then puts '[{\"filename\":\"README.md\"}]'")
  end
end

# A generated trial reaches publication without changing its YAML or trusting it as team policy.
class PrivateTrialPublicationTest < Minitest::Test
  include PrivateSetupFixture
  include CliOpeningCheckFakes
  include EvidenceFixture
  include PrivateTrialPublicationHelpers

  SUMMARY = 'A private trial records public settings and current-head evidence.'

  def test_fresh_generated_trial_renders_description_walkthrough_and_handoff
    with_setup do |root, ref|
      before = fresh_trial(root, ref)
      validation = run_check(root, ref, command: 'validate')
      review = review_for(root, ref)
      verify_publication(root, ref, validation, review)
      assert_equal before, File.read(config_path(root))
      assert_equal ['README.md'], git(root, 'diff', '--name-only', ref, @head).lines.map(&:chomp)
      assert_equal '', git(root, 'status', '--porcelain')
    end
  end

  def test_missing_results_still_apply_the_private_location_setting
    with_setup do |root, ref|
      setup_private(root, ref)
      @head = ref
      Dir.mktmpdir do |dir|
        body = publish_trial(dir, root, ref)
        assert_unfinished_private(body, root)
      end
    end
  end

  def test_private_publication_uses_native_gates_without_granting_policy
    with_setup do |root, ref|
      setup_private(root, ref)
      assert_nil Shaka::TrustedConfigSource.from_ref(root:, ref:, private_trial: true)
      assert_raises(Shaka::Error) { Shaka::TrustedConfigSource.from_ref(root:, ref:) }
      File.delete(config_path(root))
      assert_raises(Shaka::Error) { Shaka::TrustedConfigSource.from_ref(root:, ref:, private_trial: true) }
    end
  end

  def test_explicit_supported_location_choice_is_preserved
    settings = Shaka::PublicationSettings.new(current: { 'wip.include_locations' => false })
    spec = HandoffFixtures::WIP.merge('workspace' => '/synthetic/private-checkout', 'thread' => PRIVATE_LINK)
    content = description_content.merge('wip' => spec)
    body = Shaka::Publication.description(content, nil, nil, settings)
    assert_includes body, '| Workspace | REDACTED |'
    assert_includes body, '| Chat link | REDACTED |'
    refute_includes body, PRIVATE_LINK
    refute_includes body, spec.fetch('workspace')
    assert_equal PRIVATE_LINK, spec.fetch('thread')
  end

  private

  def assert_public_settings(body, ref)
    assert_includes body, 'Bound to the current candidate commit'
    assert_includes body, '| source.configuration | private/local | private/local | private/local |'
    assert_includes body, '| review.required | none | none | none |'
    assert_includes body, "| source.revision | #{([ref] * 3).join(' | ')} |"
    assert_includes body, '| wip.include_locations | true | true | true |'
    assert_includes body, "| Workspace | #{CHECKOUT} |"
    assert_includes body, "| Chat link | #{SESSION} |"
    assert_includes body, 'Local files remain local'
  end

  def assert_public_handoff(body)
    walkthrough = HandoffFixtures.walkthrough(@head)
    walkthrough['body'] = trial_walkthrough
    result = Shaka::Handoff.new(HandoffFakeGitHub.new(trial_pull(body, walkthrough))).call(head: @head)
    assert_empty result.fetch('owed')
    assert_equal @head, result.fetch('head')
    assert_includes walkthrough['body'], @head
    assert_includes walkthrough['body'], 'validate'
  end

  def trial_walkthrough
    Shaka::Publication.walkthrough(
      'identity' => HandoffFixtures::IDENTITY, 'summary' => 'The feature is verified.', 'head' => @head,
      'table' => { 'columns' => %w[Check Result], 'rows' => [%w[validate pass]] },
      'sections' => [{ 'heading' => 'Change',
                       'body' => "[Feature](https://github.com/owner/repo/blob/#{@head}/README.md)" }]
    )
  end

  def trial_pull(body, walkthrough)
    { state: 'OPEN', head: @head, labels: ['awaiting-resume'], body:,
      reviews: [walkthrough], checks: [HandoffFixtures.check('pass')], comments: [] }
  end
end
