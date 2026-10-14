# frozen_string_literal: true

module ReviewWorkflowHelper
  private

  def result
    { type: 'result', subtype: 'success', is_error: false, num_turns: 2 }
  end

  def report
    { 'user' => { 'login' => 'claude[bot]' }, 'created_at' => '2026-09-30T00:01:00Z',
      'body' => "Review complete.\n\nREVIEWED #{'a' * 40} BY anthropic/claude FINDINGS 0\n" }
  end

  def install_github(comments)
    File.write(File.join(@directory, 'comments.json'), JSON.generate([comments]))
    command = File.join(@directory, 'gh')
    File.write(command, "#!/bin/sh\ncat '#{@directory}/comments.json'\n")
    File.chmod(0o700, command)
  end

  def run_result(data = nil, outcome: 'success', comments: [])
    File.write(@execution, data.is_a?(String) ? data : JSON.generate(data)) unless data.nil?
    File.write(@summary, '')
    install_github(comments)
    environment = result_environment(data, outcome)
    output, status = Open3.capture2e(environment, 'bash', '-c', @script)
    [output, status, File.read(@summary)]
  end

  def result_environment(data, outcome = 'success')
    { 'BASH_ENV' => nil, 'PATH' => "#{@directory}:#{ENV.fetch('PATH')}",
      'GITHUB_REPOSITORY' => 'o/r', 'REVIEW_PR' => '1',
      'REVIEW_STARTED_AT' => '2026-09-30T00:00:00Z', 'EXECUTION_FILE' => data.nil? ? '' : @execution,
      'REVIEW_OUTCOME' => outcome,
      'REVIEW_HEAD' => 'a' * 40, 'GITHUB_STEP_SUMMARY' => @summary }
  end
end
