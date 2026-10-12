# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'local_evaluation_fixture_test'
require 'yaml'
require 'shaka/repository_config'

# Checks the three-ticket fixture for the issue #457 evaluation: a seed repository that
# validates, a ticket graph with two independent tickets and one dependent ticket, and no
# evaluator-only material in the public tree.
class DependencyDeliveryFixtureTest < Minitest::Test
  include LocalEvaluationFixtureAssertions

  FIXTURE = File.expand_path('../eval/fixtures/dependency_delivery', __dir__)
  SEED = File.join(FIXTURE, 'seed')
  SEED_FILES = %w[
    .agents/shaka/bin/setup .agents/shaka/bin/test .agents/shaka/bin/validate .agents/shaka/config.yml
    .github/workflows/validate.yml .ruby-version AGENTS.md Gemfile Gemfile.lock
    lib/parcel_quote.rb test/parcel_quote_test.rb
  ].freeze

  def test_fixture_has_the_complete_small_public_shape
    expected = ['fixture.yml'] + SEED_FILES.map { |path| "seed/#{path}" }
    assert_equal expected.sort, files(FIXTURE)
    fixture = YAML.safe_load_file(File.join(FIXTURE, 'fixture.yml'))
    assert_true fixture.fetch('public_safe')
    assert_false fixture.fetch('reusable_for_measured_cases')
  end

  def test_fixture_contains_no_evaluator_material_or_credentials
    files(FIXTURE).each do |relative|
      refute_match FORBIDDEN_CONTENT, File.read(File.join(FIXTURE, relative), encoding: 'UTF-8'), relative
    end
  end

  def test_tickets_form_two_independent_changes_and_one_dependent_change
    independent, dependent = blockers.partition { |_key, blocked_by| blocked_by.empty? }
    assert_equal 2, independent.size
    assert_equal [independent.map(&:first).sort], dependent.map(&:last)
  end

  def test_seed_keeps_ask_and_passes_its_own_validation
    assert_equal 'ask', Shaka::RepositoryConfig.load(root: SEED).merge.fetch('preference')
    stdout, stderr, success = FIXTURE_RUNNER.call([File.join(SEED, '.agents/shaka/bin/validate')], Dir.tmpdir)
    assert success, "#{stdout}\n#{stderr}"
    assert_match(/1 runs?, \d+ assertions?, 0 failures, 0 errors, 0 skips/, stdout)
  end

  private

  def blockers
    tickets = YAML.safe_load_file(File.join(FIXTURE, 'fixture.yml')).fetch('tickets')
    tickets.to_h { |ticket| [ticket.fetch('key'), ticket.fetch('blocked_by').sort] }
  end
end
