# frozen_string_literal: true

require 'json'
require 'open3'
require 'tempfile'
require_relative '../repository_config/review_schema'
require_relative '../usage/codex_usage'
require_relative '../usage/claude_usage'
require_relative 'path_guard'
require_relative 'process'
require_relative 'openrouter'

module Shaka
  # Keeps process diagnostics outside the candidate checkout.
  module LocalReviewDiagnostic
    private

    def save_diagnostic(text)
      return nil if text.to_s.strip.empty?

      file = Tempfile.create(['shaka-review-diagnostic-', '.txt'])
      file.write(text)
      file.close
      file.path
    end

    def save_usage(output)
      file = Tempfile.create(['shaka-review-usage-', '.json'])
      file.write(output)
      file.close
      file.path
    end

    def capture_claude_usage(result, output)
      @options[:observed_model] = ClaudePrintResult.model_attribution(result)
      @options[:usage] = save_usage(output) if @options.fetch(:capture_usage, true)
    end

    def process_failure(command, status, stderr, stdout)
      diagnostic = [stderr, stdout].reject(&:empty?).join("\n")
      failure("#{command} #{process_exit_reason(status)}", diagnostic,
              provider_errors: provider_error_messages(stdout))
    end

    def process_exit_reason(status)
      return status.message if status.is_a?(LocalReviewProcess::CleanupError)
      return "timed out after #{@options.fetch(:timeout_seconds)}s" if status.nil?
      return "output drain timed out after 2s (process exited #{status.process_status.exitstatus})" if
        status.is_a?(LocalReviewProcess::DrainTimeout)

      status.signaled? ? "killed by signal #{status.termsig}" : "exited #{status.exitstatus}"
    end

    def reviewer_process(args, input = nil)
      LocalReviewProcess.capture(args, stdin_data: input, chdir: @root,
                                       timeout: @options.fetch(:timeout_seconds),
                                       env: @path ? { 'PATH' => @path } : {})
    rescue LocalReviewProcess::CleanupError => e
      ['', e.message, e]
    end

    def reviewer_executable(name)
      LocalReviewPathGuard.safe_executable(@path || ENV.fetch('PATH', ''), name, @candidate_root)
    end

    def failure(reason, diagnostic = nil, provider_errors: [])
      result = outcome(reason, 'cli_failure', true)
               .merge('diagnostic_path' => save_diagnostic(diagnostic),
                      'guidance' => 'Inspect diagnostics. Ask the user before changing model or effort.').compact
      return result unless provider_errors.any? { |message| account_model_refused?(message) }

      result.merge('failure_cause' => 'account_model_refused', 'skip_evidence' => 'not_eligible',
                   'guidance' => 'This account refused the requested model. Keep the model and effort; ' \
                                 'ask the user to choose accessible settings before retrying. ' \
                                 'This does not establish a provider outage.')
    end

    # Codex --json separates native errors from candidate output; stderr is only diagnostic.
    def provider_error_messages(stdout)
      return [] unless @options[:reviewer] == 'openai/codex'

      stdout.lines.filter_map { |line| error_event_message(line) }
    end

    def error_event_message(line)
      event = JSON.parse(line)
      return unless event.is_a?(Hash)
      return event['message'] if event['type'] == 'error' && event['message'].is_a?(String)
      return unless event['type'] == 'turn.failed' && event['error'].is_a?(Hash)

      event.dig('error', 'message')
    rescue JSON::ParserError
      nil
    end

    # Other model/access errors remain ambiguous and require inspection, never a fallback.
    def account_model_refused?(message)
      unwrapped_model_error(message).to_s.match?(
        /\AThe ['"`][^'"`\n]+['"`] model is not supported when using Codex with a ChatGPT account\.?\z/i
      )
    end

    def unwrapped_model_error(message)
      wrapper = message.to_s.match(/\Aunexpected status 400 Bad Request:\s*(\{.*\})\z/m)
      wrapper ? JSON.parse(wrapper[1])['detail'] : message
    rescue JSON::ParserError
      nil
    end

    def invalid(reason, diagnostic = nil)
      outcome(reason, 'report_validation', true).merge('diagnostic_path' => save_diagnostic(diagnostic)).compact
    end

    def outcome(reason, stage, attempted)
      File.unlink(@report) if File.exist?(@report) && (stage != 'report_validation' || !File.size?(@report))
      { 'status' => 'not_completed', 'head' => @options[:head], 'reviewer' => @options[:reviewer],
        'attempted' => attempted, 'failure_stage' => stage, 'reason' => reason,
        'report' => stage == 'report_validation' && File.size?(@report) ? @report : nil,
        'skip_evidence' => { 'executable_missing' => 'confirmed',
                             'cli_failure' => 'requires_cause_review' }.fetch(stage, 'not_eligible'),
        'usage' => @options[:usage] }.compact
    end
  end

  # The only path that may claim a local review process was actually launched.
  class LocalReviewCli
    include LocalReviewDiagnostic
    include LocalReviewOpenrouter

    def initialize(options, root:, report:, candidate_root:, path: nil)
      @options = options
      @root = root
      @report = report
      @candidate_root = candidate_root
      @path = path
    end

    def run(prompt)
      case @options.fetch(:reviewer)
      when 'openai/codex' then codex(prompt)
      when 'anthropic/claude' then claude(prompt)
      when 'xai/grok' then grok(prompt)
      when 'deepseek/openrouter' then openrouter(prompt)
      end
    end

    private

    def codex(prompt)
      executable = reviewer_executable('codex')
      return missing('codex') unless executable

      args = [executable, 'exec', '-s', 'read-only', '--ignore-rules', '--ignore-user-config',
              '-c', 'skills.include_instructions=false',
              '--skip-git-repo-check', '--json', '-o', @report, *codex_choices, '-']
      stdout, stderr, status = reviewer_process(args, prompt)
      return process_failure('codex exec', status, stderr, stdout) unless status&.success?

      @options[:usage] = CodexUsage.announced_session(stdout) if @options.fetch(:capture_usage, true)
      invalid('codex exec returned no review', stdout) unless File.size?(@report)
    end

    # --ignore-user-config also drops the user's model, so the CLI default runs unless one is named.
    # The effort becomes configuration text, so this site checks it whatever the caller did.
    def codex_choices
      RepositoryConfig::ReviewSchema.effort_level!(effort, 'Codex effort') if effort

      [*(['-m', @options[:model]] if @options[:model]),
       *(['-c', %(model_reasoning_effort="#{effort}")] if effort)]
    end

    def claude(prompt)
      executable = reviewer_executable('claude')
      return missing('claude') unless executable

      output, stderr, status = claude_process(executable, prompt)
      return process_failure('claude -p', status, stderr, output) unless status&.success?

      claude_result(output)
    rescue JSON::ParserError
      invalid('claude -p returned malformed JSON', output)
    end

    def claude_process(executable, prompt)
      args = [executable, '-p', '--permission-mode', 'plan', '--permission-prompts', 'none', '--restricted',
              '--safe-mode', '--strict-mcp-config']
      args.push('--model', @options[:model]) if @options[:model]
      args.push('--effort', effort) if effort
      args.push('--output-format', 'json', '-')
      reviewer_process(args, prompt)
    end

    def claude_result(output)
      result = JSON.parse(output)
      return invalid('claude -p returned non-object JSON', output) unless result.is_a?(Hash)

      return failure('claude -p reported an error', output) if result['is_error']
      return invalid('claude -p returned no review', output) unless valid_claude_result?(result)

      capture_claude_usage(result, output)
      File.write(@report, result.fetch('result'))
      nil
    end

    def valid_claude_result?(result) = result['result'].is_a?(String) && !result['result'].strip.empty?

    def grok(prompt)
      executable = reviewer_executable('grok')
      return missing('grok') unless executable

      file = prompt_file(prompt)
      output = grok_process(executable, file.path)
      return output if output.is_a?(Hash)

      File.write(@report, output)
      invalid('grok returned no review') if output.empty?
    ensure
      File.unlink(file.path) if file && File.exist?(file.path)
    end

    def prompt_file(prompt)
      file = Tempfile.create('shaka-review-prompt-')
      file.write(prompt)
      file.close
      file
    end

    def grok_process(executable, prompt_path)
      args = [executable, '--prompt-file', prompt_path, *(['-m', @options[:model]] if @options[:model])]
      args.push('--reasoning-effort', effort) if effort
      args.push('--output-format', 'plain', '--permission-mode', 'plan', '--disable-web-search', '--no-subagents')
      output, stderr, status = reviewer_process(args)
      status&.success? ? output : process_failure('grok', status, stderr, output)
    end

    def missing(name) = outcome("#{name} is not on PATH", 'executable_missing', false)

    def effort = @options[:effort]
  end
end
