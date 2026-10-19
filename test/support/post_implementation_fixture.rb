# frozen_string_literal: true

require_relative '../review_prompt_file_test'

module PostImplementationFixture
  include ReviewPromptFileFixture

  private

  def checkpoint_trace(root) = JSON.parse(File.read(File.join(root, 'trace.json')))
  def option(trace, flag) = trace.fetch('args').fetch(trace.fetch('args').index(flag) + 1)

  def assert_checkpoint_prompt(root)
    trace = checkpoint_trace(root)
    instructions = trace.fetch('prompt').split('--- BEGIN PACKET DATA', 2).first
    directory = File.expand_path('../../skills/shaka/references', __dir__)
    guide = File.read(File.join(directory, 'writing.md'), encoding: 'UTF-8')
    assert_includes instructions, guide[/^## Plain language and organization\n.*?(?=^## )/m].strip
    refute_includes instructions, '## Review evidence'
    refute_includes instructions, File.read(File.join(directory, 'publication.md'), encoding: 'UTF-8')
    trace
  end

  def commit_candidate_instructions(root)
    File.write(File.join(root, '.agents/agent-workflow.yml'),
               YAML.dump(seam('post_implementation' => { 'enabled' => false, 'model' => 'candidate-model' })))
    directory = File.join(root, 'skills/shaka/references')
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, 'writing.md'), 'Candidate-only writing instruction')
    commit!(root, 'candidate instructions')
    git!(root, 'rev-parse', 'HEAD').strip
  end

  def remove_provider(bin)
    File.unlink(File.join(bin, 'codex'))
    write_executable(bin, 'ruby', "#!/bin/sh\nexec #{RbConfig.ruby} \"$@\"\n")
    FileUtils.ln_s(TEST_GIT, File.join(bin, 'git'))
  end

  def invalid_report(bin, head, kind)
    return fake_checkpoint(bin, head, report_head: 'a' * 40) if kind == :stale

    report = kind == :technical ? "REVIEWED #{head} BY openai/codex EFFORT medium FINDINGS 0" : '{}'
    write_executable(bin, 'codex', "#!/usr/bin/env ruby\nFile.write(ARGV[ARGV.index('-o')+1], #{report.dump})\n")
  end

  def fake_checkpoint(bin, head, conclusion: 'Proceed', concerns: [], report_head: head)
    report = { head: report_head, conclusion:, reasons: ['A useful existing check is restored.'],
               concerns:, alternative: 'A guide sentence leaves the failure intact.',
               verification_adequacy: ADEQUACY }
    write_executable(bin, 'codex', <<~RUBY)
      #!/usr/bin/env ruby
      require 'json'
      File.write(ENV.fetch('REVIEW_TRACE'), JSON.generate({ args: ARGV, prompt: STDIN.read }))
      File.write(ARGV.fetch(ARGV.index('-o') + 1), #{JSON.generate(report).dump})
    RUBY
  end

  def fake_claude(bin, head)
    report = { head:, conclusion: 'Proceed', reasons: ['Useful change'], concerns: [], alternative: 'No change',
               verification_adequacy: ADEQUACY }
    write_executable(bin, 'claude', <<~RUBY)
      #!/usr/bin/env ruby
      require 'json'
      File.write(ENV.fetch('REVIEW_TRACE'), JSON.generate({ args: ARGV, prompt: STDIN.read }))
      puts JSON.generate(result: #{JSON.generate(report).dump})
    RUBY
  end

  def checkpoint_packet(bin, content = CHECKPOINT_CONTENT)
    packet = File.join(bin, 'packet.json')
    File.write(packet, JSON.generate(content))
    ['--content-file', packet]
  end

  # A test sets @packet to run on other description content.
  def run_checkpoint(root, base, head, bin, *options)
    packet_options = options.delete(:without_packet) ? [] : checkpoint_packet(bin, @packet || CHECKPOINT_CONTENT)
    output, error, status = Open3.capture3(
      { 'PATH' => "#{bin}:#{ENV.fetch('PATH')}", 'REVIEW_TRACE' => File.join(root, 'trace.json') },
      COMMAND, 'post-implementation', 'run', '--root', root, '--base', base, '--head', head,
      '--ref', base, *packet_options, *options
    )
    parse_result(output, error, status)
  end

  def parse_result(output, error, status)
    [JSON.parse(output), status]
  rescue JSON::ParserError
    flunk "#{output}\n#{error}"
  end
end
