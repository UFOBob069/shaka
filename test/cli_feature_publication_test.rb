# frozen_string_literal: true

require_relative 'evidence_fixture'
require_relative 'cli_opening_check_fakes'

class CliFeaturePublicationTest < Minitest::Test
  include CliOpeningCheckFakes
  include EvidenceFixture

  COMMAND = File.expand_path('../skills/shaka/scripts/shaka', __dir__)
  SUMMARY = 'Feature descriptions report the settings used.'

  def test_description_without_settings_flags_still_blocks_live_configuration_diff
    with_checkout do |root, ref|
      @head = ref
      @files = [{ 'filename' => '.agents/shaka/private' }]
      Dir.mktmpdir do |dir|
        _output, error, status = publish(dir, root)
        refute_predicate status, :success?
        assert_includes error, 'Feature PR contains Shaka configuration changes'
        refute_path_exists File.join(dir, 'published.md')
      end
    end
  end

  def test_separate_migration_flow_publishes_without_claiming_check_evidence
    with_checkout do |root, ref|
      @head = ref
      @files = [{ 'filename' => '.agents/shaka/config.yml' }]
      Dir.mktmpdir do |dir|
        _output, error, status = publish(dir, root, '--publication-flow', 'migration')
        assert_predicate status, :success?, error
        assert_includes File.read(File.join(dir, 'published.md')), 'UNKNOWN: rerun missing evidence'
      end
    end
  end

  def test_result_flags_bind_actual_results_and_refuse_missing_review
    with_checkout do |root, ref|
      @head = ref
      @files = []
      Dir.mktmpdir do |dir|
        arguments = result_flags(dir, root, ref)
        assert_bound_results(dir, root, arguments)
        assert_missing_review(dir, root, arguments)
      end
    end
  end

  def test_saved_review_result_reaches_the_canonical_usage_table
    with_checkout do |root, ref|
      @head = ref
      @files = []
      Dir.mktmpdir { |dir| publish_usage_snapshot(dir, root, ref) }
    end
  end

  private

  def publish_usage_snapshot(dir, root, ref)
    flags = result_flags(dir, root, ref)
    result = JSON.parse(File.read(flags.last))
    record = USAGE_RECORD.merge('commits' => [ref], 'columns' => [USAGE_COLUMN.merge('input' => '579')],
                                'host' => 'codex', 'contribution' => 'review')
    File.write(flags.last, JSON.generate(result.merge('usage_records' => [record])))
    content = description_content.merge('usage' => { 'note' => '', 'records' => [] })
    _out, error, status = publish(dir, root, *flags, content:)
    assert_predicate status, :success?, error
    assert_usage_body(dir)
  end

  def assert_usage_body(dir)
    body = File.read(File.join(dir, 'published.md'))
    assert_includes body, '| codex | 579 | 0 | 0 |'
    assert_equal 1, body.scan('<!-- usage-columns ').size
  end

  def assert_bound_results(dir, root, arguments)
    _output, error, status = publish(dir, root, *arguments)
    assert_predicate status, :success?, error
    linked = %r{\[`\h{7}`\]\(https://github\.com/[^)]+/commit/\h{40}\)}
    assert_match(%r{\| Before push: validation \| trusted/team at #{linked} \| validate \|},
                 File.read(File.join(dir, 'published.md')))
  end

  def assert_missing_review(dir, root, arguments)
    _output, error, status = publish(dir, root, *arguments[0...-2])
    refute_predicate status, :success?
    assert_includes error, 'rerun affected validation/review'
  end

  def result_flags(dir, root, ref)
    paths = %w[validation review].map { |name| File.join(dir, "#{name}.json") }
    File.write(paths.first, JSON.generate(run_check(root, ref, command: 'validate')))
    File.write(paths.last, JSON.generate(review_check(root, ref)))
    ['--ref', ref, '--validation-result', paths.first, '--review-result', paths.last]
  end

  def publish(dir, root, *flags, content: description_content)
    write_fake_commands(dir)
    path = File.join(dir, 'content.json')
    File.write(path, JSON.generate(content))
    Open3.capture3({ 'PATH' => "#{dir}:#{ENV.fetch('PATH')}", 'HOME' => dir }, COMMAND,
                   'description', 'shakacode/shaka', '1', '--root', root, '--content-file', path, *flags)
  end

  def fake_gh
    source = super.gsub('owner/repo', 'shakacode/shaka').gsub("'c' * 40", @head.dump)
    source = source.sub("'changed_files' => 0", "'changed_files' => #{@files.size}")
    source.sub("then puts '[]'", "then puts #{JSON.generate(@files).dump}")
  end
end
