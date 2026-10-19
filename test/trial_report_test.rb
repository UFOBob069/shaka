# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/trial/command'
require 'tempfile'

class TrialReportFixture < Minitest::Test
  URL = 'https://github.com/shakacode/shaka/pull/359'
  HEAD = 'a' * 40

  def setup
    @calls = []
    @looked_up = []
    @candidate_commit = HEAD
    @private = false
    @body = "Workflow version: https://github.com/shakacode/shaka/commit/#{HEAD}"
    build_client
  end

  def build_client
    owner = self
    @github = Object.new
    @github.define_singleton_method(:api_list) { |path| owner.api(path) }
    @github.define_singleton_method(:api) { |*args, **kwargs| owner.api(*args, **kwargs) }
    @github.define_singleton_method(:reply) do |**kwargs|
      Shaka::GitHub.allocate.send(:reply_mark, kwargs[:key])
      owner.calls << kwargs
      { 'body' => kwargs[:body] }
    end
  end

  attr_reader :calls

  def api(path, **options)
    @looked_up << path
    raise 'Reporting should not require label permissions' unless options.empty?
    return { 'sha' => HEAD } if path.include?('/commits/')
    return [{ 'sha' => @candidate_commit }] if path.include?('/commits?')
    return { 'state' => 'open', 'base' => { 'repo' => { 'full_name' => 'shakacode/shaka', 'private' => false } } } if
      path == 'repos/shakacode/shaka/pulls/359'
    return { 'private' => @private, 'visibility' => @private ? 'private' : 'public' } if path == 'repos/team/project'

    { 'body' => @body }
  end

  private

  def cli(path, status: 0)
    original = Shaka::GitHub.method(:new)
    client = @github
    Shaka::GitHub.define_singleton_method(:new) { |*| client }
    capture_io do
      assert_equal status, Shaka::Trial::Command.run(['report', URL, '--content-file', path])
    end
  ensure
    Shaka::GitHub.define_singleton_method(:new, original)
  end

  def report(extra = {})
    content = { 'id' => 'example', 'candidate_head' => HEAD, 'verdict' => 'keep',
                'summary' => 'Useful; needed one correction.' }.merge(extra)
    Shaka::Trial::Report.new(URL, content, github: @github, results: @github).run
  end
end

class TrialReportTest < TrialReportFixture
  def test_reports_a_public_result_without_label_permissions
    result = report('result_url' => 'https://github.com/team/project/pull/7')
    assert_includes result['body'], HEAD
    assert_includes result['body'], 'team/project/pull/7'
    assert_includes result['body'], 'keep'
    assert_operator calls.last[:key].length, :<=, 64
  end

  def test_refuses_a_private_result_before_any_comment_is_written
    @private = true
    assert_raises(Shaka::Error) { report('result_url' => 'https://github.com/team/project/pull/7') }
    assert_empty calls
  end

  def test_refuses_result_without_matching_workflow_provenance
    @body = 'No evidence this version was used'
    assert_raises(Shaka::Error) { report('result_url' => 'https://github.com/team/project/pull/7') }
    assert_empty calls
  end

  def test_supports_a_public_safe_summary_without_a_private_link
    result = report('private_result' => true)
    assert_includes result['body'], 'Private result; link withheld'
    assert_includes result['body'], 'Reported by the tester'
  end

  def test_requires_a_result_or_explicit_private_result
    assert_raises(Shaka::Error) { report }
    assert_empty calls
  end

  def test_refuses_private_links_embedded_in_the_summary
    @private = true
    assert_raises(Shaka::Error) do
      report('private_result' => true, 'summary' => 'See HTTPS://GitHub.com/team/project/pull/7')
    end
    assert_empty calls
  end

  def test_refuses_private_links_in_other_github_url_forms
    @private = true
    ['See https://www.github.com/team/project/pull/7', 'See github.com/team/project/pull/7',
     'See https://github.com:443/team/project/pull/7', 'See http://WWW.GitHub.com:80/team/project'].each do |summary|
      assert_raises(Shaka::Error, summary) { report('private_result' => true, 'summary' => summary) }
    end
    assert_empty calls
  end

  def test_refuses_dot_segments_that_change_the_linked_repository
    ['https://github.com/team/project/../../acme/secret/pull/1',
     'https://github.com/team/project/%2e%2e/%2E%2E/acme/secret',
     '[notes](https://github.com/team/project/\\.\\./\\.\\./acme/secret)',
     '[notes](https://github.com/team/project|/../../acme/secret)',
     'See https://github.com/team/project)/../../acme/secret', 'See [notes](https://github.com/team/project/..)',
     '[notes](https://github.com/team/project"/../../acme/secret)'].each do |summary|
      assert_raises(Shaka::Error, summary) { report('private_result' => true, 'summary' => summary) }
    end
    assert_empty(@looked_up.grep(%r{\Arepos/(team/project|acme/secret)\z}))
    assert_empty calls
  end

  def test_refuses_github_mentions_outside_a_checked_link
    ['Hosted on github.com.', 'See https://gist.github.com/team/project', 'See https://github.com\\acme\\secret',
     'See https://github.com:8443/team/project', 'See https://user@github.com/team/project',
     'See https://github%2Ecom/team/project', "See https://\uFF47ithub.com/team/project",
     "See https://github\u3002com/acme/secret", "See https://git\u00ADhub.com/acme/secret",
     'See https://github.com/team/project?next=https://github.com/acme/secret',
     'See https://github.com/team/project#https://www.github.com/acme/secret',
     'See [notes](https://github\\.com/acme/secret)'].each do |summary|
      assert_raises(Shaka::Error, summary) { report('private_result' => true, 'summary' => summary) }
    end
    assert_empty calls
  end

  def test_checks_the_repository_a_markdown_destination_keeps
    ['See [notes](https://github.com/team/project_)', 'See [notes](https://github.com/team/project.)'].each do |summary|
      assert_raises(Shaka::Error, summary) { report('private_result' => true, 'summary' => summary) }
    end
    assert_equal 2, (@looked_up & %w[repos/team/project_ repos/team/project.]).size
    assert_empty calls
  end

  def test_html_character_references_stay_inert_in_the_published_summary
    result = report('private_result' => true, 'summary' => 'See [notes](https://github&#46;com/acme/secret)')
    assert_includes result['body'], 'github&amp;#46;com'
    refute_includes @looked_up, 'repos/acme/secret'
  end

  def test_publishes_public_links_in_other_github_url_forms
    result = report('private_result' => true,
                    'summary' => 'See www.github.com/team/project, http://WWW.GitHub.com:80/team/project, ' \
                                 'https://github.com:443/team/project/pull/7, and https://github.com/team/project/.')
    assert_includes result['body'], 'www.github.com/team/project'
    assert_includes @looked_up, 'repos/team/project'
  end

  def test_rejects_a_revision_outside_the_candidate_pr
    @candidate_commit = 'b' * 40
    assert_raises(Shaka::Error) { report('private_result' => true) }
    assert_empty calls
  end

  def test_supports_long_trial_ids_and_markdown_github_links
    result = report('id' => 'a' * 48, 'summary' => 'See `https://github.com/team/project/pull/7`.',
                    'result_url' => 'https://github.com/team/project/pull/7')
    assert_includes result['body'], 'a' * 48
    assert_operator calls.last[:key].length, :<=, 64
  end
end

class TrialReportCommandTest < TrialReportFixture
  def test_cli_handles_malformed_summary_links_without_a_backtrace
    Tempfile.create(['trial-report', '.json']) do |file|
      file.write(JSON.generate('id' => 'bad-link', 'candidate_head' => HEAD, 'verdict' => 'revise',
                               'private_result' => true, 'summary' => 'See https://github.com/team/project/{'))
      file.flush
      output, error = cli(file.path, status: 1)
      assert_empty output
      assert_includes error, 'shaka trial:'
      assert_empty calls
    end
  end

  def test_cli_rejects_github_root_urls_without_a_backtrace
    Tempfile.create(['trial-report', '.json']) do |file|
      file.write(JSON.generate('id' => 'root-link', 'candidate_head' => HEAD, 'verdict' => 'revise',
                               'private_result' => true, 'summary' => 'See https://github.com/.'))
      file.flush
      _output, error = cli(file.path, status: 1)
      assert_match(/\Ashaka trial:/, error)
      assert_empty calls
    end
  end

  def test_cli_publishes_a_report_from_json
    content = { 'id' => 'cli-example', 'candidate_head' => HEAD, 'verdict' => 'revise',
                'summary' => 'Useful with one correction.', 'result_url' => 'https://github.com/team/project/pull/7' }
    Tempfile.create(['trial-report', '.json']) do |file|
      file.write(JSON.generate(content))
      file.flush
      output, error = cli(file.path)
      assert_empty error
      assert_includes JSON.parse(output)['body'], 'revise'
    end
  end
end
