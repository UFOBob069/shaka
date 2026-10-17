# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'tmpdir'
require 'fileutils'
require 'open3'

class DocsNavigationTest < Minitest::Test
  AGENT_LINKS = <<~MARKDOWN
    Read [the review guide](../skills/shaka/references/review.md#choose).
    See [upstream](https://github.com/shakacode/shaka/blob/main/skills/shaka/references/delivery.md).
    [guide]: <skills/shaka/references/local-review.md>
    <a href="https://github.com/shakacode/shaka/tree/main/skills/shaka/references">all</a>
    Bare: https://github.com/shakacode/shaka/blob/v1/skills/shaka/references/review.md
    Autolink: <https://github.com/shakacode/shaka/blob/main/skills/shaka/references/publication.md>
    [section](../skills/shaka/references#review) and [query](../skills/shaka/references?page=1)
    <a href=../skills/shaka/references/review.md>unquoted</a>
  MARKDOWN

  def check(sidebar, page = '# What to expect')
    Dir.mktmpdir do |root|
      File.write(File.join(root, 'expected-experience.md'), page)
      File.write(File.join(root, 'sidebars.json'), JSON.generate(sidebar))
      Open3.capture3('ruby', File.expand_path('../bin/check-docs-navigation', __dir__), root)
    end
  end

  def test_new_page_missing_from_navigation_fails
    output, _, status = check('docsSidebar' => [])
    refute_predicate status, :success?
    assert_includes output, 'expected-experience'
  end

  def test_nested_document_is_reachable
    _, _, status = check('docsSidebar' => [{ 'type' => 'category', 'label' => 'Start',
                                             'items' => ['expected-experience'] }])
    assert_predicate status, :success?
  end

  def test_stale_document_entry_fails
    output, _, status = check('docsSidebar' => %w[expected-experience deleted-guide])
    refute_predicate status, :success?
    assert_includes output, 'deleted-guide'
  end

  def test_links_to_agent_instructions_fail
    output, _, status = check({ 'docsSidebar' => ['expected-experience'] }, AGENT_LINKS)
    refute_predicate status, :success?
    assert_equal 9, output.scan('expected-experience.md -> ').size
  end

  def test_configuration_links_and_prose_pass
    page = <<~MARKDOWN
      Copy [the defaults](../skills/shaka/config/defaults.yml) and read [settings](settings.md).
      The agent keeps its procedures in its own references folder.
    MARKDOWN
    _, _, status = check({ 'docsSidebar' => ['expected-experience'] }, page)
    assert_predicate status, :success?
  end
end
