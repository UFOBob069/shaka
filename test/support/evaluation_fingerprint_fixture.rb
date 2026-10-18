# frozen_string_literal: true

module EvaluationFingerprintFixture
  def with_machine_alias(value)
    previous = ENV.fetch('SHAKA_MACHINE_ALIAS', nil)
    ENV['SHAKA_MACHINE_ALIAS'] = value
    yield
  ensure
    ENV['SHAKA_MACHINE_ALIAS'] = previous
  end

  def run_with_evidence(evidence)
    trial = Shaka::Evaluation::HarborTrial.new(runtime: @runtime, usage: @usage,
                                               tasks: { tasks.first.fetch('id') => @task },
                                               directory: File.join(@directory, 'captures'), fingerprints: evidence)
    plans = tasks.map { it.merge('tier' => 2) }
    trial.run(plans, budget: budget, records: File.join(@directory, 'records')) do |task, id|
      record(task, id, 0)
    end
  end

  def capture_native_files(host, second_version: '9.8.7', lock_digest: nil, mutate: false)
    FileUtils.mkdir_p(File.join(@skill, 'config'))
    File.write(File.join(@skill, 'SKILL.md'), 'load references and helpers')
    File.write(File.join(@skill, 'config/workflow.yml'), 'synthetic workflow')
    digest = lock_digest || Shaka::Evaluation::SkillSnapshot.read(@skill).fetch('harbor_digest')
    files = native_files(host, second_version, digest)
    File.write(File.join(@directory, 'native-files.json'), JSON.generate(files))
    append_native_script(mutate)
  end

  def native_files(host, second_version, digest)
    lock = { skills: [{ source: File.realpath(@skill), digest: digest }],
             agent: { name: host, model_name: 'synthetic/requested-model', kwargs: { reasoning_effort: 'medium' } } }
    { 'lock.json' => JSON.generate(lock),
      'agent/sessions/first.jsonl' => JSON.generate(native_row(host, '9.8.7')),
      'agent/sessions/nested/subagents/second.jsonl' => JSON.generate(native_row(host, second_version)) }
  end

  def native_row(host, version)
    return { type: 'session_meta', payload: { cli_version: version } } if host == 'codex'

    { type: 'user', version: version }
  end

  def append_native_script(mutate)
    path = File.join(@bin, 'harbor')
    script = File.read(path).sub(/^exit\(mode.*\n?\z/, '')
    script << <<~CODE
      JSON.parse(File.read(File.join(root, 'native-files.json'))).each do |path, bytes|
        File.write(File.join(trial, path), bytes)
      end
    CODE
    script << "File.write(#{File.join(@skill, 'SKILL.md').inspect}, 'changed')\n" if mutate
    File.write(path, script)
  end

  def observed_usage
    @usage.define_singleton_method(:read) do |**|
      { 'models' => [{ 'provider' => 'openai', 'configured_model' => 'configured',
                       'routed_model' => 'UNKNOWN', 'effort' => 'high', 'input_tokens' => 1,
                       'cached_input_tokens' => 0, 'cache_write_tokens' => 0, 'output_tokens' => 1,
                       'reasoning_tokens' => 0 }],
        'cache_neutral_dollars' => 1, 'billed_dollars' => 0.5 }
    end
  end

  def native_evidence
    { tasks.first.fetch('id') => { 'machine_alias' => 'private-machine',
                                   'fixture_ruby_version' => '3.4.6', 'judge_model_id' => 'N/A' } }
  end
end
