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

  def check(sidebar, page = '# What to expect', files = {})
    Dir.mktmpdir do |repository|
      docs = File.join(repository, 'docs')
      tree = { 'docs/expected-experience.md' => page, 'docs/sidebars.json' => JSON.generate(sidebar) }
      tree.merge(files).each do |path, text|
        FileUtils.mkdir_p(File.dirname(File.join(repository, path)))
        File.write(File.join(repository, path), text)
      end
      Open3.capture3('ruby', File.expand_path('../bin/check-docs-navigation', __dir__), docs)
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
    agent_line = output.lines.grep(/\ALink a human guide/).first
    assert_equal 9, agent_line.scan('expected-experience.md -> ').size
  end

  def test_configuration_links_and_prose_pass
    page = <<~MARKDOWN
      Copy [the defaults](../skills/shaka/config/defaults.yml) and read [settings](settings.md).
      The agent keeps its procedures in its own references folder.
    MARKDOWN
    _, _, status = check({ 'docsSidebar' => %w[expected-experience settings] }, page,
                         'docs/settings.md' => '# Settings', 'skills/shaka/config/defaults.yml' => "{}\n")
    assert_predicate status, :success?
  end

  GUIDE = "GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#%s'\n"

  SETTINGS = <<~MARKDOWN
    # Settings
    ## Add a second reviewer
    ## `review.ci_review_wait`
    ## Examples
    ## Examples
    ### See [the guide](#examples) first
    <a id="opening_check"></a>
    ```text
    ## Not a heading
    ```
  MARKDOWN

  RESOLVABLE = <<~MARKDOWN
    Read [one](settings.md#add-a-second-reviewer), [two](settings.md#reviewci_review_wait),
    [three](settings.md#examples-1), [four](settings.md#see-the-guide-first),
    [five](<settings.md#opening_check>), and [here](#what-to-expect).

    # What to expect
    ```text
    [ignored](missing.md)
    ```
    `[ignored](missing.md)` and [skill](../skills/shaka/SKILL.md#start).
  MARKDOWN

  def check_links(page, files = {})
    check({ 'docsSidebar' => %w[expected-experience settings] }, page, { 'docs/settings.md' => SETTINGS }.merge(files))
  end

  def test_resolvable_links_and_anchors_pass
    skill = "# Start\nSee [settings](../../docs/settings.md).\n"
    output, _, status = check_links(RESOLVABLE, 'skills/shaka/SKILL.md' => skill,
                                                'skills/shaka/lib/guide.rb' => format(GUIDE, 'add-a-second-reviewer'))
    assert_predicate status, :success?, output
  end

  BROKEN = ['docs/expected-experience.md -> gone.md (missing file)',
            'docs/expected-experience.md -> settings.md#nope (missing anchor)',
            'docs/expected-experience.md -> settings.md#not-a-heading (missing anchor)',
            'docs/expected-experience.md -> guide.mdx#absent (missing anchor)',
            'docs/expected-experience.md -> settings.md#also-nope (missing anchor)',
            'skills/shaka/SKILL.md -> references/missing.md (missing file)'].freeze

  def test_missing_files_and_anchors_fail
    page = "[gone](gone.md), [anchor](settings.md#nope), [code block](settings.md#not-a-heading)\n" \
           "[mdx](guide.mdx#absent)\n[defined]: settings.md#also-nope\n[^1]: A footnote, not a link.\n"
    output, _, status = check_links(page, 'skills/shaka/SKILL.md' => "[ref](references/missing.md)\n",
                                          'docs/guide.mdx' => '# Guide')
    refute_predicate status, :success?
    assert_equal BROKEN.sort, output.lines.map(&:strip).grep(/ -> /).sort
  end

  def test_docs_anchor_emitted_by_code_must_resolve
    guide = "#{format(GUIDE, 'add-another-reviewer')}PAGE = 'https://github.com/shakacode/shaka/blob/main/docs/gone.md'\n"
    output, _, status = check_links('# What to expect', 'skills/shaka/lib/guide.rb' => guide)
    refute_predicate status, :success?
    assert_includes output, 'skills/shaka/lib/guide.rb -> docs/settings.md#add-another-reviewer (missing anchor)'
    assert_includes output, 'skills/shaka/lib/guide.rb -> docs/gone.md (missing file)'
  end
end
