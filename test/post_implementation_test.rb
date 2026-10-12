# frozen_string_literal: true

require_relative 'support/post_implementation_fixture'

class PostImplementationTest < Minitest::Test
  include PostImplementationFixture

  def test_defaults_invoke_a_reviewer_and_keep_product_evidence_separate
    with_repository do |root, base, head, bin|
      fake_checkpoint(bin, head)
      result, status = run_checkpoint(root, base, head, bin)

      assert_predicate status, :success?, result.inspect
      assert_equal 'post_implementation', result.fetch('purpose')
      trace = assert_checkpoint_prompt(root)
      assert_equal 'gpt-6.1-sol', option(trace, '-m')
      assert_includes trace.fetch('prompt'), 'Restore the missing-check error'
      refute_includes File.read(result.fetch('report')), 'REVIEWED'
    end
  end

  def test_trusted_settings_and_prompt_reach_the_cli
    settings = { 'post_implementation' => { 'model' => 'chosen-model', 'effort' => 'high',
                                            'prompt_file' => '.agents/codex-prompt.md' } }
    with_repository(settings) do |root, base, head, bin|
      fake_checkpoint(bin, head)
      _, status = run_checkpoint(root, base, head, bin)
      trace = assert_checkpoint_prompt(root)

      assert_predicate status, :success?
      assert_includes trace.fetch('args'), 'model_reasoning_effort="high"'
      assert trace.fetch('prompt').start_with?('Codex-only instructions')
    end
  end

  def test_explicit_overrides_select_another_provider_and_trusted_prompt
    with_repository({ 'post_implementation' => { 'model' => 'old-model',
                                                 'effort' => 'low' } }) do |root, base, head, bin|
      fake_claude(bin, head)
      result, status = run_checkpoint(root, base, head, bin, '--reviewer', 'anthropic/claude', '--model', 'sonnet',
                                      '--effort', 'high', '--prompt-file', '.agents/codex-prompt.md')
      trace = checkpoint_trace(root)

      assert_predicate status, :success?, result.inspect
      assert_equal %w[sonnet high], [option(trace, '--model'), option(trace, '--effort')]
      assert trace.fetch('prompt').start_with?('Codex-only instructions')
    end
  end

  def test_capitalized_trusted_identity_keeps_its_model_when_task_changes_only_case
    settings = { 'reviewer' => 'Anthropic/Claude', 'model' => 'sonnet' }
    with_repository({ 'post_implementation' => settings }) do |root, base, head, bin|
      fake_claude(bin, head)
      result, status = run_checkpoint(root, base, head, bin, '--reviewer', 'ANTHROPIC/CLAUDE')
      assert_predicate status, :success?, result.inspect
      assert_equal 'anthropic/claude', result.fetch('reviewer')
      assert_equal 'sonnet', option(checkpoint_trace(root), '--model')
    end
  end

  def test_capitalized_task_identity_uses_the_existing_reviewer_parser
    with_repository do |root, base, head, bin|
      fake_claude(bin, head)
      result, status = run_checkpoint(root, base, head, bin, '--reviewer', 'Anthropic/Claude', '--model', 'sonnet')
      assert_predicate status, :success?, result.inspect
      assert_equal 'anthropic/claude', result.fetch('reviewer')
    end
  end

  def test_claude_xhigh_reaches_the_cli
    settings = { 'reviewer' => 'anthropic/claude', 'effort' => 'xhigh' }
    with_repository({ 'post_implementation' => settings }) do |root, base, head, bin|
      fake_claude(bin, head)
      result, status = run_checkpoint(root, base, head, bin)
      assert_predicate status, :success?, result.inspect
      assert_equal 'xhigh', option(checkpoint_trace(root), '--effort')
    end
  end

  def test_codex_max_reaches_the_cli
    with_repository({ 'post_implementation' => { 'effort' => 'max' } }) do |root, base, head, bin|
      fake_checkpoint(bin, head)
      result, status = run_checkpoint(root, base, head, bin)
      assert_predicate status, :success?, result.inspect
      assert_includes checkpoint_trace(root).fetch('args'), 'model_reasoning_effort="max"'
    end
  end

  def test_candidate_configuration_never_selects_execution_settings
    with_repository do |root, base, _head, bin|
      head = commit_candidate_instructions(root)
      fake_checkpoint(bin, head)
      result, status = run_checkpoint(root, base, head, bin)

      assert_predicate status, :success?
      assert_equal 'gpt-6.1-sol', result.fetch('requested_model')
      prompt = checkpoint_trace(root).fetch('prompt')
      refute_includes prompt.split('--- BEGIN PACKET DATA', 2).first, 'Candidate-only writing instruction'
      assert_includes prompt, 'Candidate-only writing instruction'
    end
  end

  def test_nonproceed_conclusions_and_unresolved_concerns_block_readiness
    [['Simplify/reframe', []], ['Do not merge', []],
     ['Proceed', ['Audience mismatch remains']]].each do |verdict, concerns|
      with_repository do |root, base, head, bin|
        fake_checkpoint(bin, head, conclusion: verdict, concerns:)
        result, status = run_checkpoint(root, base, head, bin)

        assert_predicate status, :success?
        refute result.fetch('ready')
      end
    end
  end
end

class PostImplementationFailureTest < Minitest::Test
  include PostImplementationFixture

  def test_stale_malformed_and_technical_reports_do_not_complete
    %i[stale malformed technical].each do |kind|
      with_repository do |root, base, head, bin|
        invalid_report(bin, head, kind)
        result, status = run_checkpoint(root, base, head, bin)

        refute_predicate status, :success?
        assert_equal 'report_validation', result.fetch('failure_stage')
      end
    end
  end

  def test_invalid_settings_and_missing_prompt_stop_before_invocation
    [{ 'effort' => 'invalid' }, { 'reviewer' => 'unknown/provider' }, { 'model' => '' },
     { 'prompt_file' => '.agents/missing.md' }, { 'prompt_file' => '../outside.md' }].each do |settings|
      with_repository({ 'post_implementation' => settings }) do |root, base, head, bin|
        result, status = run_checkpoint(root, base, head, bin)

        refute_predicate status, :success?
        assert_equal 'setup_failure', result.fetch('failure_stage')
        refute_path_exists File.join(root, 'trace.json')
      end
    end
  end

  def test_process_failure_and_timeout_do_not_complete
    ["echo 'credentials unavailable' >&2; exit 1", 'sleep 4'].each do |script|
      with_repository do |root, base, head, bin|
        write_executable(bin, 'codex', "#!/bin/sh\n#{script}\n")
        result, status = run_checkpoint(root, base, head, bin, '--timeout-seconds', '1')

        refute_predicate status, :success?
        assert_equal 'cli_failure', result.fetch('failure_stage')
      end
    end
  end

  def test_missing_provider_executable_has_an_explicit_outcome
    with_repository do |root, base, head, bin|
      remove_provider(bin)
      original = ENV.fetch('PATH', nil)
      ENV['PATH'] = bin
      result, status = run_checkpoint(root, base, head, bin)

      refute_predicate status, :success?
      assert_equal 'executable_missing', result.fetch('failure_stage')
    ensure
      ENV['PATH'] = original
    end
  end

  def test_opt_out_does_not_build_a_packet_or_load_an_inactive_prompt
    [{ 'enabled' => false }, {}].each do |settings|
      settings['prompt_file'] = '.agents/missing.md'
      with_repository({ 'post_implementation' => settings }) do |root, base, head, bin|
        options = settings.key?('enabled') ? [] : ['--opt-out', 'Maintainer decision']
        result, status = run_checkpoint(root, base, head, bin, *options, :without_packet)

        assert_predicate status, :success?, result.inspect
        assert_equal 'opted_out', result.fetch('status')
        refute_path_exists File.join(root, 'trace.json')
      end
    end
  end

  def test_trusted_and_explicit_opt_outs_never_claim_successful_review
    [{ 'enabled' => false }, {}].each do |settings|
      with_repository({ 'post_implementation' => settings }) do |root, base, head, bin|
        options = settings.empty? ? ['--opt-out', 'Maintainer opted out for this task'] : []
        result, status = run_checkpoint(root, base, head, bin, *options)

        assert_predicate status, :success?
        assert_equal 'opted_out', result.fetch('status')
        refute result.fetch('ready')
        refute_path_exists File.join(root, 'trace.json')
      end
    end
  end
end

class PostImplementationSchemaTest < Minitest::Test
  include RepositoryConfigTestHelpers

  def test_trusted_schema_accepts_and_resolves_checkpoint_prompt
    settings = { 'reviewer' => 'Anthropic/Claude', 'model' => 'sonnet', 'effort' => 'high',
                 'prompt_file' => '.agents/checkpoint.md' }
    with_repository('review' => review_policy('post_implementation' => settings)) do |root|
      File.write(File.join(root, '.agents/checkpoint.md'), 'Compare actual outcome and cost')
      config = Shaka::RepositoryConfig.load(root:)

      assert_equal settings, config.review.fetch('post_implementation')
    end
  end

  def test_missing_trusted_prompt_never_uses_a_candidate_replacement
    policy = review_policy('post_implementation' => { 'prompt_file' => '.agents/absent.md' })
    with_repository('review' => policy) do |root|
      system(TEST_GIT, '-C', root, 'init', '--quiet', exception: true)
      system(TEST_GIT, '-C', root, 'add', '.', exception: true)
      system(TEST_GIT, '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
             'commit', '-qm', 'trusted', exception: true)
      File.write(File.join(root, '.agents/absent.md'), 'Candidate instructions')

      assert_raises(Shaka::Error) { Shaka::TrustedConfigSource.load(root:, ref: 'HEAD') }
    end
  end
end
