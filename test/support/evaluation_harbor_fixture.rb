# frozen_string_literal: true

module EvaluationHarborFixture
  def setup_harbor(host: 'codex', mode: 'success', timeout: 10, docker: nil)
    prepare_harbor_files(mode, host)
    tools = { 'harbor' => File.join(@bin, 'harbor'), 'docker' => docker || File.join(@bin, 'docker'),
              'source' => @source }
    @runtime = Shaka::Evaluation::HarborRuntime.new(tools: tools, credential: @credential, skill: @skill,
                                                    path: "#{@bin}:#{ENV.fetch('PATH')}", profile: {
                                                      'host' => host, 'model' => 'synthetic-model',
                                                      'version' => '1.2.3',
                                                      'reasoning_effort' => 'medium', 'timeout_seconds' => timeout
                                                    })
    fake_usage
  end

  def prepare_harbor_files(mode, host)
    @bin, @source, @skill, @task = %w[bin harbor-source skill task].map { |name| File.join(@directory, name) }
    [@bin, @source, @skill, @task].each { |path| FileUtils.mkdir_p(path) }
    @credential = File.join(@directory, 'credential')
    write_subscription(host)
    File.write(File.join(@directory, 'fake-mode'), mode)
    fake_executable('git', "puts '#{Shaka::Evaluation::HarborRuntime::REVISION}' if ARGV.include?('rev-parse')")
    %w[harbor docker].each do |name|
      fake_executable(name, File.read(File.expand_path("../fixtures/evaluation_harbor/#{name}.txt", __dir__)))
    end
  end

  def write_subscription(host)
    credential = if host == 'codex'
                   JSON.generate({ 'tokens' => { 'access_token' => 'private-subscription-secret' } })
                 else
                   'private-subscription-secret'
                 end
    File.write(@credential, credential)
  end

  def fake_usage
    @usage = Object.new
    @usage.define_singleton_method(:rate_card_hash) { "sha256:#{'b' * 64}" }
    @usage.define_singleton_method(:read) do |host:, files:|
      raise 'Missing descendant usage' unless files.size == 2 && %w[codex claude-code].include?(host)

      { 'models' => [], 'cache_neutral_dollars' => 1, 'billed_dollars' => 0.5 }
    end
  end

  def fake_executable(name, source)
    path = File.join(@bin, name)
    File.write(path, "#!#{RbConfig.ruby}\n#{source}")
    File.chmod(0o755, path)
  end

  def harbor_trial
    Shaka::Evaluation::HarborTrial.new(runtime: @runtime, usage: @usage,
                                       tasks: { tasks.first.fetch('id') => @task },
                                       directory: File.join(@directory, 'captures'))
  end

  def harbor_run(account = budget, count: 1)
    plans = tasks(count).map { |task| task.merge('tier' => 2) }
    harbor_trial.run(plans, budget: account, records: File.join(@directory, 'records')) do |task, id, capture|
      @capture = capture
      record(task, id, 0)
    end
  end

  def saved_harbor_record = JSON.parse(File.read(saved_records.fetch(0)))
  def observed_harbor = JSON.parse(File.read(File.join(@directory, 'observed.json')))

  def with_controller_secrets
    previous = ENV.to_h
    %w[OPENAI_API_KEY ANTHROPIC_API_KEY GITHUB_TOKEN HTTPS_PROXY].each { |key| ENV[key] = 'synthetic-private-secret' }
    yield
  ensure
    ENV.replace(previous)
  end
end
