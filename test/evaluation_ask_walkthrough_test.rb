# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../eval/lib/shaka/evaluation/delivery_ask'
require_relative 'support/evaluation_ask_fixture'

class EvaluationAskWalkthroughTest < Minitest::Test
  include EvaluationAskFixture

  def with_body(body)
    packet = evidence
    packet['walkthrough'] = receipt(22, 'fixture-agent', body).merge('readback_finished_at' => 3.0)
    packet['current_walkthrough'] = receipt(22, 'fixture-agent', body).merge('readback_finished_at' => 15.0)
    packet
  end

  def test_walkthrough_requires_identity_section_and_terminal_comment_marker
    [walkthrough_body.sub(/🤖[^\n]+/, ''), walkthrough_body.sub('## Repair', 'Repair'),
     walkthrough_body.sub('This is a COMMENT, not an approval.', 'Approved!'),
     "#{walkthrough_body}Later text"].each do |body|
      assert_fails with_body(body), 'walkthrough'
    end
  end

  def test_native_short_label_and_full_sha_forms_bind_the_same_commit
    full = walkthrough_body.sub("[`#{HEAD[0, 7]}`]", "[`#{HEAD}`]")
    bare = walkthrough_body.sub("[`#{HEAD[0, 7]}`](https://github.com/#{REPOSITORY}/commit/#{HEAD})", "`#{HEAD}`")
    [walkthrough_body, full, bare].each { |body| assert grader.call(with_body(body))['passed'] }
  end

  def test_footer_label_repository_and_full_commit_target_cannot_differ
    { "[`#{HEAD[0, 7]}`]" => '[`bbbbbbb`]', "/commit/#{HEAD}" => "/commit/#{'b' * 40}",
      "/#{REPOSITORY}/commit/" => '/another/cell/commit/' }.each do |from, value|
      assert_fails with_body(walkthrough_body.sub(from, value)), 'walkthrough'
    end
  end

  def test_quoted_sections_or_code_links_do_not_qualify
    body = walkthrough_body.sub("[`#{HEAD[0, 7]}`]", "[`#{HEAD}`]")
    ['## Repair', body.lines.find { |line| line.start_with?('Read [') }.strip].each do |quoted|
      assert_fails with_body(body.sub(quoted, "```markdown\n#{quoted}\n```")), 'walkthrough'
    end
  end

  def fenced_body(opening, closing)
    section = walkthrough_body[/## Repair\nRead[^\n]+/]
    walkthrough_body.sub(section, "#{opening}\n#{section}\n#{closing}")
  end

  def test_tilde_and_indented_fences_cannot_supply_artifact_structure
    [['~~~markdown', '~~~'], ['  ```ruby', '  ```'], ['  ~~~~text', '  ~~~~~']].each do |opening, closing|
      assert_fails with_body(fenced_body(opening, closing)), 'walkthrough'
    end
  end

  def test_shorter_wrong_or_missing_closers_do_not_end_a_fence
    [["````ruby\n```", '````'], ["~~~ruby\n```", '~~~'], ['~~~ruby', '']].each do |opening, closing|
      assert_fails with_body(fenced_body(opening, closing)), 'walkthrough'
    end
  end

  def test_a_longer_matching_fence_allows_real_structure_after_it
    body = walkthrough_body.sub('## Repair', "~~~markdown\nexample only\n~~~~\n## Repair")
    assert grader.call(with_body(body))['passed']
  end

  def test_inline_code_examples_do_not_supply_links
    line = walkthrough_body.lines.find { |text| text.start_with?('Read [') }.strip
    ['`', '``'].each do |ticks|
      assert_fails with_body(walkthrough_body.sub(line, "#{ticks}#{line}#{ticks}")), 'walkthrough'
    end
  end

  def test_inline_code_in_a_real_heading_is_valid
    assert grader.call(with_body(walkthrough_body.sub('## Repair', '## `Repair`')))['passed']
  end

  def test_code_link_must_resolve_to_changed_final_blob_lines
    { "https://github.com/#{REPOSITORY}/blob/" => ['https://github.com/another/cell/blob/'],
      "/blob/#{HEAD}/" => ["/blob/#{'b' * 40}/"],
      '/code.rb#L2-L3' => %w[/unchanged.rb#L2-L3 /code.rb#L0 /code.rb#L5 /code.rb#L3-L2
                             /code.rb#L2-L5] }.each do |from, values|
      values.each { |value| assert_fails with_body(walkthrough_body.sub(from, value)), 'walkthrough' }
    end
  end

  def test_encoded_file_names_are_resolved_against_the_changed_blob_inventory
    packet = with_body(walkthrough_body.sub('code.rb', 'some%20code.rb'))
    packet['changed_files'] = { 'lib/some code.rb' => 4 }
    assert grader.call(packet)['passed']
  end

  def test_driver_ledger_cannot_reorder_a_later_failure_behind_a_pass
    packet = evidence
    packet['verifications'].unshift(verification(2, 'FAIL'))
    assert_fails packet, 'driver_pass'
  end

  def test_readback_queue_does_not_allow_checks_or_walkthroughs_to_arrive_late
    packet = evidence
    packet['terminal']['received_at'] = 6.0
    packet['checks'][0]['observed_at'] = 7.0
    assert_fails packet, 'required_checks'
    packet['walkthrough']['readback_finished_at'] = 7.0
    assert_fails packet, 'walkthrough'
    packet = evidence
    packet['current_walkthrough']['readback_finished_at'] = 9.0
    assert_fails packet, 'walkthrough'
  end
end
