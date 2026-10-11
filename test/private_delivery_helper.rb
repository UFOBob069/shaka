# frozen_string_literal: true

require_relative 'evidence_fixture'
require_relative 'configuration_layout_fixture'
require_relative 'cli_opening_check_fakes'
require_relative 'handoff_helper'

module PrivateDeliveryEvidence
  private

  def evidence_files
    paths = %w[validation review].map { |kind| File.join(@state, "#{kind}.json") }
    File.write(paths.first, validation_result)
    File.write(paths.last, review_result)
    paths
  end

  def validation_result
    output, = capture_io do
      assert_equal 0, Shaka::Evidence::Command.run(
        ['run', '--root', @root, '--ref', @ref, '--repository', 'owner/repo', '--command', 'validate']
      )
    end
    binding = Shaka::Evidence::Result.bind(JSON.parse(output), root: @root, ref: @ref, head: @ref,
                                                               repository: 'owner/repo')
    assert_equal 'bound', binding['status']
    output
  end

  def review_result(*options)
    reviewer = invoke('reviewer', '--implementer', 'openai/codex')['reviewer']
    Dir.mktmpdir('review-cli', @state) do |bin|
      write_executable(bin, reviewer.split('/').last, delivery_reviewer)
      run_review_cli(bin, reviewer, options)
    end
  end

  def run_review_cli(bin, reviewer, options)
    output, error, status = Open3.capture3(
      { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'REVIEW_TRACE' => File.join(@state, 'reviewer.json') },
      PrivateDeliveryFixture::COMMAND, 'review', 'run', '--root', @root, '--base', @ref, '--head', @ref,
      '--reviewer', reviewer, '--settings-ref', @ref, '--repository', 'owner/repo', *options
    )
    assert_predicate status, :success?, "#{output}\n#{error}"
    output
  end

  def assert_reviewer_arguments(*expected)
    args = JSON.parse(File.read(File.join(@state, 'reviewer.json')))['args'].each_cons(2).to_a
    expected.each { |pair| assert_includes args, pair }
  end

  def delivery_reviewer
    <<~'RUBY'
      #!/usr/bin/env ruby
      require 'json'
      prompt = if ARGV.include?('--prompt-file')
                 File.read(ARGV.fetch(ARGV.index('--prompt-file') + 1))
               else
                 STDIN.read
               end
      File.write(ENV.fetch('REVIEW_TRACE'), JSON.generate(args: ARGV, prompt: prompt))
      report = prompt[/REVIEWED [0-9a-f]{40} BY \S+ EFFORT \S+ FINDINGS/, 0] + " 0\n"
      case File.basename($PROGRAM_NAME)
      when 'codex' then File.write(ARGV.fetch(ARGV.index('-o') + 1), report)
      when 'claude' then puts JSON.generate(result: report)
      else puts report
      end
    RUBY
  end

  def publish_description(validation, review, opening: false, **expected)
    wip = HandoffFixtures::WIP.merge('revision' => "feature @ #{@ref}")
    path = File.join(@state, 'description.json')
    File.write(path, JSON.generate(description_content.merge('wip' => wip)))
    flags = opening ? ['--opening-reviewer', 'anthropic/claude'] : []
    invoke('description', '--content-file', path,
           '--validation-result', validation, '--review-result', review, *flags, **expected)
  end

  def assert_reviewer(expected)
    assert_equal expected, invoke('reviewer', '--implementer', 'openai/codex')['reviewer']
  end

  def assert_stale_handoff(result)
    assert(result['owed'].any? { |item| item.include?('publish one for') })
    assert(result['owed'].any? { |item| item.include?('refresh it') })
  end

  def assert_native_gate
    snapshot = invoke('pr')
    assert_equal 'github', snapshot['requiredChecksSource']
    assert_equal(['live-gate'], snapshot['requiredChecks'].map { |check| check['name'] })
  end
end

module PrivateDeliveryFixture
  include EvidenceFixture
  include ConfigurationLayoutFixture
  include CliOpeningCheckFakes
  include PrivateDeliveryEvidence

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  SUMMARY = 'The feature now works.'

  private

  def with_trial
    Dir.mktmpdir('shaka-private-delivery') do |root|
      @root = root
      initialize_trial
      Dir.mktmpdir('shaka-delivery-api') do |state|
        @state = state
        initialize_api
        yield
      end
    end
  end

  def initialize_trial
    git(@root, 'init', '--quiet')
    File.write(File.join(@root, 'feature'), 'feature')
    git(@root, 'add', 'feature')
    commit(@root)
    @ref = git(@root, 'rev-parse', 'HEAD')
    write_private
    File.write(File.join(@root, '.git/info/exclude'), "/.agents/shaka/\n")
  end

  def initialize_api
    write_executable(@state, 'gh', File.read(File.join(__dir__, 'support/private_delivery_gh.rb')))
    File.write(File.join(@state, 'pull.json'), JSON.generate(
                                                 'snapshot' => { 'headRefOid' => @ref, 'state' => 'OPEN',
                                                                 'baseRefName' => 'main' }, 'checks' => []
                                               ))
  end

  def write_private
    FileUtils.mkdir_p(File.join(@root, '.agents/shaka/bin'))
    create_new_commands(@root)
    data = config.merge('wip' => { 'include_locations' => false }, 'opening_check' => { 'external_enabled' => false })
    File.write(File.join(@root, '.agents/shaka/config.yml'), YAML.dump(data))
  end

  def update_private
    path = File.join(@root, '.agents/shaka/config.yml')
    data = YAML.safe_load_file(path)
    yield data
    File.write(path, YAML.dump(data))
  end

  def alter_pull
    path = File.join(@state, 'pull.json')
    pull = JSON.parse(File.read(path))
    yield pull
    File.write(path, JSON.generate(pull))
  end

  def invoke(command, *, exit_code: 0, error: nil)
    positional = command == 'reviewer' ? [] : ['owner/repo', '1']
    output, stderr, status = Open3.capture3({ 'PATH' => "#{@state}:#{ENV.fetch('PATH')}", 'HOME' => @state },
                                            COMMAND, command, *positional, '--root', @root, '--ref', @ref, *)
    assert_equal exit_code, status.exitstatus, stderr
    assert_includes stderr, error if error
    JSON.parse(output) unless output.empty?
  end

  def publish_delivery
    publish_description(*evidence_files)
    invoke('walkthrough', '--head', @ref, '--content-file', walkthrough_file)
  end

  def walkthrough_file
    path = File.join(@state, 'walkthrough.json')
    data = { 'identity' => { 'agent' => 'Codex' },
             'summary' => "[Feature](https://github.com/owner/repo/blob/#{@ref}/feature) passed validation and review." }
    File.write(path, JSON.generate(data))
    path
  end
end
