# frozen_string_literal: true

require_relative 'publication_test'
require 'shaka/usage/publisher_attribution'

# Builds the `shaka comments --head SHA` output a description lists human comments from.
module HumanCommentsFixture
  HEAD = 'c' * 40
  REPO = { 'full_name' => 'owner/repo' }.freeze
  URL = 'https://github.com/owner/repo/pull/7'
  IDENTITY = '🤖 Codex · OpenAI · gpt-test · high'
  REPLY = "<!-- shaka:reply:maintainer-1 -->\nResponded to the [review](#{URL}#discussion_r1) by `ann`.\n\n" \
          "#{IDENTITY}\n\nRemoved both placeholders. The example now runs in one chat.".freeze

  def pull(body: '', author: 'ann', fork: false)
    { 'body' => body, 'number' => 7, 'user' => { 'login' => author },
      'head' => { 'sha' => HEAD, 'repo' => fork ? { 'full_name' => 'fork/repo' } : REPO },
      'base' => { 'repo' => REPO } }
  end

  def packet(**rows)
    { 'visibility' => 'private', 'head' => HEAD, 'review_threads' => [], 'trust_sources' => [],
      'excluded_interactions' => [], 'issue_comments' => [], 'review_summaries' => [],
      'inline_comments' => [] }.merge(rows.transform_keys(&:to_s))
  end

  def inline(id, author, body, thread: 'T1', resolved: false)
    { 'id' => id, 'author' => author, 'body' => body, 'url' => "#{URL}#discussion_r#{id}",
      'thread_id' => thread, 'is_resolved' => resolved }
  end

  def issue_comment(id, author, body, at: nil)
    { 'id' => id, 'author' => author, 'body' => body, 'url' => "#{URL}#issuecomment-#{id}", 'created_at' => at }
  end

  def review(id, author, body, state: 'COMMENTED', at: nil)
    { 'id' => id, 'author' => author, 'body' => body, 'state' => state,
      'url' => "#{URL}#pullrequestreview-#{id}", 'created_at' => at }
  end

  # comments is what `shaka description --comments PATH` read from the file, or nil without the flag.
  # summaries is the agent's one line for each longer comment, keyed by the comment's URL.
  def describe(comments, pull: self.pull, summaries: nil, settings: nil, **changes)
    content = { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.',
                'walkthrough' => PublicationRegressionTest::WALKTHROUGH, 'deployment' => 'none',
                'steps_besides_merging' => 'none', 'table' => PublicationRegressionTest::TABLE,
                'intent' => INTENT, 'verification' => VERIFICATION,
                'provenance' => PUBLIC_PROVENANCE, 'usage' => PublicationRegressionTest::USAGE_OBJECT,
                'details' => [] }.merge(changes)
    content['human_comments'] = comments if comments
    content['human_comment_summaries'] = summaries if summaries
    Shaka::Publication.description(content, nil, pull, settings && Shaka::PublicationSettings.new(current: settings))
  end

  LONG = 'It is a little confusing what internal testers are versus external testers, and listings feel abstract.'

  def rows(rendered) = rendered[Shaka::HumanComments::BLOCK].to_s.lines.map(&:chomp).grep(/\A\| (?!From |--- )/)

  def cells(rendered) = rows(rendered).map { |row| row.delete_prefix('| ').delete_suffix(' |').split(' | ') }

  # Each row's cells at the given columns: From, Said, Response, Status.
  def columns(rendered, *indexes) = cells(rendered).map { |row| row.values_at(*indexes) }

  # The word that marks a row someone other than the PR author wrote; the author's has none.
  def roles(rendered) = cells(rendered).map { |row| row.first[/\A(\*\*Reviewer\*\*|Unverified) /, 1] }

  # The count line without the commit it was read at.
  def counts(rendered) = rendered[/^(.*) · read at `ccccccc`$/, 1]

  def published(comment) = wrap(describe(packet(issue_comments: [comment])))

  def wrap(rendered) = "<!-- shaka:begin -->\n#{rendered}<!-- shaka:end -->"

  # The pull request after a push that followed the published read.
  def moved(body) = pull(body:).merge('head' => { 'sha' => 'd' * 40, 'repo' => REPO })

  # What the comment reader keeps of a comment or review whose author it could not trust.
  def excluded(id, author, kind: 'issue_comment', withheld: true, **fields)
    anchor = kind == 'review_summary' ? 'pullrequestreview-' : 'issuecomment-'
    { 'kind' => kind, 'id' => id, 'author' => author, 'url' => "#{URL}##{anchor}#{id}",
      'body_withheld' => withheld, 'trust' => 'untrusted' }.merge(fields.transform_keys(&:to_s))
  end
end

# On https://github.com/shakacode/shaka/pull/427 the author's five review comments shared a
# login with forty agent posts, and the description listed none of them.
class PublicationHumanCommentsTest < Minitest::Test
  include HumanCommentsFixture

  def test_a_person_s_comment_is_listed_and_an_agent_post_from_the_same_login_is_not
    rendered = describe(packet(inline_comments: [inline(1, 'ann', 'you mean chat, not owner.', resolved: true),
                                                 inline(2, 'ann', REPLY, resolved: true)]))

    assert_equal [['[ann](https://github.com/ann)', "[“you mean chat\\, not owner\\.”](#{URL}#discussion_r1)",
                   "[“Removed both placeholders\\. The example now runs in one chat\\.”](#{URL}#discussion_r2)",
                   'Resolved']], cells(rendered)
    assert_includes rendered, "## Human comments\n\nNone open · 1 from the PR author · read at `ccccccc`\n\n"
  end

  def test_a_reviewer_s_open_comments_lead_the_author_s_and_the_count_says_who_wrote_them
    rendered = describe(packet(inline_comments: [inline(1, 'ann', 'A settled note.', thread: 'T1', resolved: true),
                                                 inline(2, 'Bob', 'This is inconsistent.', thread: 'T2'),
                                                 inline(3, 'ann', 'An open note.', thread: 'T3')]))

    assert_equal ['**Reviewer**', nil, nil], roles(rendered)
    assert_equal [['**Open**'], ['**Open**'], ['Resolved']], columns(rendered, 3)
    assert_equal '**2 open** · 1 from 1 reviewer, 2 from the PR author', counts(rendered)
  end

  def test_the_count_says_how_many_people_reviewed
    rendered = describe(packet(issue_comments: [issue_comment(1, 'Bob', 'One.'), issue_comment(2, 'bob', 'Two.'),
                                                issue_comment(3, 'Cy', 'Three.')]))

    assert_equal '**3 open** · 3 from 2 reviewers', counts(rendered)
  end

  def test_the_login_decides_author_or_reviewer_whatever_its_letter_case
    rendered = describe(packet(issue_comments: [issue_comment(1, 'ANN', 'Mine.')]), pull: pull(author: 'ann'))

    assert_equal '[ANN](https://github.com/ANN)', cells(rendered).first.first
  end

  def test_a_bot_is_not_a_person_and_its_reply_in_the_thread_is_the_response
    rendered = describe(packet(inline_comments: [inline(1, 'ann', 'Is this a bug?'),
                                                 inline(2, 'claude[bot]', 'No. The caller checks it first.')]))

    assert_equal [['[ann](https://github.com/ann)', "[“Is this a bug\\?”](#{URL}#discussion_r1)",
                   "[“No\\. The caller checks it first\\.”](#{URL}#discussion_r2)", '**Open**']], cells(rendered)
  end

  def test_a_conversation_comment_is_open_until_an_agent_post_links_exactly_that_comment
    reply = "#{IDENTITY}\n\nRenamed it, as [the request](#{URL}#issuecomment-10) asks."
    rendered = describe(packet(issue_comments: [issue_comment(1, 'Bob', 'Please split this PR.'),
                                                issue_comment(10, 'Bob', 'And rename the flag.'),
                                                issue_comment(11, 'ann', reply)]))

    assert_equal [['—', '**No reply**'],
                  ["[“Renamed it\\, as the request asks\\.”](#{URL}#issuecomment-11)", 'Replied']],
                 columns(rendered, 2, 3)
  end

  def test_the_latest_answer_is_shown_whichever_kind_of_post_it_is
    earlier = "#{IDENTITY}\n\nFirst answer to [the request](#{URL}#issuecomment-1)."
    later = "#{IDENTITY}\n\nRevised, per [the request](#{URL}#issuecomment-1)."
    rendered = describe(packet(review_summaries: [review(9, 'ann', later, at: '2026-10-02T00:00:00Z')],
                               issue_comments: [issue_comment(1, 'Bob', 'Split it.', at: '2026-09-30T00:00:00Z'),
                                                issue_comment(2, 'ann', earlier, at: '2026-10-01T00:00:00Z')]))

    assert_equal [["[“Revised\\, per the request\\.”](#{URL}#pullrequestreview-9)"]], columns(rendered, 2)
  end

  def test_a_person_s_line_that_starts_with_the_robot_emoji_is_still_listed
    rendered = describe(packet(issue_comments: [issue_comment(1, 'Bob', '🤖 this bot reply missed my point')]))

    assert_equal ['**No reply**'], columns(rendered, 3).flatten
  end

  def test_a_reply_that_links_the_comment_under_issues_also_answers_it
    reply = "#{IDENTITY}\n\nDone, per #{URL.sub('/pull/', '/issues/')}#issuecomment-1."
    rendered = describe(packet(issue_comments: [issue_comment(1, 'Bob', 'Please split this PR.'),
                                                issue_comment(2, 'ann', reply)]))

    assert_equal ['Replied'], cells(rendered).map(&:last)
  end

  def test_changes_requested_stay_open
    blocked = packet(review_summaries: [review(1, 'Bob', 'Needs a test.', state: 'CHANGES_REQUESTED')])

    assert_equal ['**Changes requested**'], cells(describe(blocked)).map(&:last)
  end

  def test_changes_requested_close_once_that_reviewer_approves
    rendered = describe(packet(review_summaries: [review(1, 'Bob', 'Needs a test.', state: 'CHANGES_REQUESTED'),
                                                  review(2, 'Bob', '', state: 'APPROVED')]))
    verdicts = cells(rendered).map { |row| [row[1][/\A\[.*\]/], row.last] }

    assert_equal [['[“Needs a test\\.”]', 'Approved later'], ['[Approved]', 'Approved']], verdicts
    assert_equal 'None open · 2 from 1 reviewer', counts(rendered)
  end

  def test_an_approval_submitted_later_closes_the_request_even_when_its_review_was_started_first
    request = review(2, 'Bob', 'Needs a test.', state: 'CHANGES_REQUESTED', at: '2026-10-01T00:00:00Z')
    approval = review(1, 'Bob', '', state: 'APPROVED', at: '2026-10-02T00:00:00Z')
    rendered = describe(packet(review_summaries: [approval, request]))

    assert_equal [['Approved'], ['Approved later']], columns(rendered, 3)
  end

  def test_a_dismissed_review_is_settled
    rendered = describe(packet(review_summaries: [review(1, 'Bob', 'Needs a test.', state: 'DISMISSED')]))

    assert_equal [['Dismissed']], columns(rendered, 3)
    assert_equal 'None open · 1 from 1 reviewer', counts(rendered)
  end

  def test_a_pending_draft_and_a_review_that_only_carries_inline_comments_are_not_listed
    rendered = describe(packet(review_summaries: [review(1, 'ann', 'My unsubmitted draft.', state: 'PENDING'),
                                                  review(2, 'ann', '')],
                               issue_comments: [issue_comment(3, 'ann', 'Listed.')]))

    assert_equal 1, rows(rendered).size
    refute_includes rendered, 'unsubmitted'
  end

  def test_a_person_s_comment_that_opens_with_an_ordinary_hidden_comment_is_still_listed
    rendered = describe(packet(issue_comments: [issue_comment(1, 'Bob', "<!-- from my template -->\nSplit this PR."),
                                                issue_comment(2, 'Bob', "<!-- TODO:mine -->\nAnd rename it."),
                                                issue_comment(3, 'ann', "<!-- grokbot:triage -->\nTriaged.")]))

    assert_equal [["[“Split this PR\\.”](#{URL}#issuecomment-1)"], ["[“And rename it\\.”](#{URL}#issuecomment-2)"]],
                 columns(rendered, 1)
  end

  def test_a_bot_summary_that_links_a_conversation_comment_does_not_answer_it
    rendered = describe(packet(issue_comments: [issue_comment(1, 'Bob', 'Please split this PR.'),
                                                issue_comment(2, 'summary[bot]', "See #{URL}#issuecomment-1.")]))

    assert_equal [['—', '**No reply**']], columns(rendered, 2, 3)
  end
end

# A comment that is already on the pull request is not repeated unless it is very short; the
# agent summarizes a longer one in a line, and the list links to it.
class PublicationHumanCommentSummaryTest < Minitest::Test
  include HumanCommentsFixture

  ASKED = "#{URL}#issuecomment-1".freeze

  def test_a_longer_comment_shows_the_agent_s_summary_and_a_short_one_its_own_words
    rendered = describe(packet(issue_comments: [issue_comment(1, 'Bob', LONG), issue_comment(2, 'Bob', 'huh?')]),
                        summaries: { ASKED => 'Finds the tester terms unclear; wants template notation.' })

    assert_equal [["[Finds the tester terms unclear\\; wants template notation\\.](#{ASKED})"],
                  ["[“huh\\?”](#{URL}#issuecomment-2)"]], columns(rendered, 1)
    refute_includes rendered, 'a little confusing'
  end

  def test_a_longer_comment_without_a_summary_is_refused_and_named
    error = assert_raises(Shaka::Error) { describe(packet(issue_comments: [issue_comment(1, 'Bob', LONG)])) }

    assert_includes error.message, "needs a one-line summary for each longer human comment: #{ASKED}"
  end

  def test_a_summary_for_a_comment_the_list_quotes_or_does_not_hold_is_refused
    short = packet(issue_comments: [issue_comment(1, 'Bob', 'huh?'), issue_comment(2, 'ann', REPLY)])

    [ASKED, "#{URL}#issuecomment-2", "#{URL}#issuecomment-9"].each do |url|
      error = assert_raises(Shaka::Error) { describe(short, summaries: { url => 'A summary.' }) }
      assert_includes error.message, "names a comment the list does not summarize: #{url}"
    end
  end

  def test_a_summary_is_one_line_of_at_most_thirty_words
    long = packet(issue_comments: [issue_comment(1, 'Bob', LONG)])

    ["Two\nlines.", ' ', (['word'] * 31).join(' '), 7].each do |summary|
      error = assert_raises(Shaka::Error) { describe(long, summaries: { ASKED => summary }) }
      assert_includes error.message, 'one line of at most 30 words'
    end
  end

  def test_markdown_in_a_summary_stays_inside_its_cell
    rendered = describe(packet(issue_comments: [issue_comment(1, 'Bob', LONG)]),
                        summaries: { ASKED => 'Wants a | b and [x](https://evil.example) gone' })

    assert_equal [["[Wants a \\| b and \\[x\\]\\(https\\:\\/\\/evil\\.example\\) gone](#{ASKED})"]],
                 columns(rendered, 1)
  end

  def test_only_a_row_the_list_shows_needs_its_summary
    hidden = "#{URL}#issuecomment-2"
    comments = packet(issue_comments: [issue_comment(1, 'Bob', LONG), issue_comment(2, 'ann', "#{LONG} Second.")])
    one_row = { 'pr_description.max_human_comments' => 1 }

    both = { ASKED => 'First.', hidden => 'Second.' }

    assert_equal 1, rows(describe(comments, summaries: { ASKED => 'First.' }, settings: one_row)).size
    assert_equal 1, rows(describe(comments, summaries: both, settings: one_row)).size
    assert_includes assert_raises(Shaka::Error) { describe(comments, summaries: { ASKED => 'First.' }) }.message, hidden
  end

  def test_summaries_wait_unused_while_no_new_read_is_passed
    refute_includes describe(nil, summaries: { ASKED => 'A summary.' }), 'Human comments'
  end
end

# A repository can turn the list off or change how many rows it shows.
class PublicationHumanCommentSettingsTest < Minitest::Test
  include HumanCommentsFixture

  def test_a_repository_that_turned_the_list_off_gets_none_and_keeps_none
    off = { 'pr_description.show_human_comments' => false }
    comments = packet(issue_comments: [issue_comment(1, 'ann', 'A note.')])

    refute_includes describe(comments, settings: off), 'Human comments'
    refute_includes describe(nil, pull: pull(body: published(issue_comment(2, 'ann', 'A note.'))), settings: off),
                    'Human comments'
  end

  def test_an_unread_setting_leaves_the_list_on
    comments = packet(issue_comments: [issue_comment(1, 'ann', 'A note.')])

    [{}, { 'pr_description.show_human_comments' => 'UNKNOWN' }].each do |current|
      assert_equal 1, rows(describe(comments, settings: current)).size
    end
  end

  def test_the_row_cap_follows_the_repository_s_setting
    comments = packet(issue_comments: (1..5).map { |id| issue_comment(id, 'ann', "Note #{id}.") })
    rendered = describe(comments, settings: { 'pr_description.max_human_comments' => 2 })

    assert_equal 2, rows(rendered).size
    assert_includes rendered, '_3 more not shown; open comments come first._'
  end
end

# On a public repository anyone can comment or submit a review, so the reader withholds what
# an unverified account wrote and the list gives that account no standing.
class PublicationUnverifiedCommentsTest < Minitest::Test
  include HumanCommentsFixture

  def test_a_withheld_comment_is_linked_for_the_reader_never_quoted_and_not_counted_open
    rendered = describe(packet(excluded_interactions: [excluded(5, 'outsider'),
                                                       excluded(6, 'scanner[bot]', trust: 'metadata_only')]))

    assert_equal [['Unverified [outsider](https://github.com/outsider)',
                   "[Not read by the agent](#{URL}#issuecomment-5)", '—', 'Not read']], cells(rendered)
    assert_equal 'None open · 1 unverified', counts(rendered)
  end

  def test_an_unverified_account_s_review_shows_no_verdict
    reviews = [excluded(5, 'outsider', kind: 'review_summary', withheld: false, state: 'APPROVED'),
               excluded(6, 'outsider', kind: 'review_summary', state: 'CHANGES_REQUESTED'),
               excluded(7, 'outsider', kind: 'review_summary', state: 'APPROVED')]
    rendered = describe(packet(excluded_interactions: reviews))

    assert_equal %w[Unverified Unverified], roles(rendered)
    assert_equal [['Not read'], ['Not read']], columns(rendered, 3)
    refute_match(/Approved|Changes requested/, rendered)
  end

  def test_an_unread_comment_follows_the_open_ones_and_leads_the_settled_ones
    rendered = describe(packet(inline_comments: [inline(1, 'ann', 'Settled.', thread: 'T1', resolved: true),
                                                 inline(2, 'Bob', 'Open.', thread: 'T2')],
                               excluded_interactions: [excluded(5, 'outsider')]))

    assert_equal ['**Reviewer**', 'Unverified', nil], roles(rendered)
    assert_equal '**1 open** · 1 from 1 reviewer, 1 from the PR author, 1 unverified', counts(rendered)
  end
end

# Whatever a comment holds, its quotation stays inside its cell.
class PublicationHumanCommentQuotationTest < Minitest::Test
  include HumanCommentsFixture

  # Each note is the publisher's own wording for a host it cannot read, placed by the comment
  # renderer, so rewording a note or moving it fails here.
  def test_the_response_skips_a_publisher_note_under_the_agent_s_identity_line
    hosts = [{}, { 'CLAUDE_CODE_SESSION_ID' => 'none' }, { 'CODEX_THREAD_ID' => 'none' }]

    hosts.each do |host|
      content = { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'Shortened the prompt.' }
      noted = Shaka::PublisherAttribution.prepare(content, environment: host.merge('HOME' => '/nonexistent'))

      assert_includes Shaka::Publication.comment(noted), "_#{noted.fetch('publisher_note')}_"
      assert_equal [["[“Shortened the prompt\\.”](#{URL}#discussion_r2)"]],
                   columns(answered(Shaka::Publication.comment(noted)), 2), host
    end
  end

  def test_the_response_keeps_an_agent_s_own_italic_first_line
    assert_equal [["[“\\_UNKNOWN cause\\; unable to reproduce\\.\\_”](#{URL}#discussion_r2)"]],
                 columns(answered("#{IDENTITY}\n\n_UNKNOWN cause; unable to reproduce._"), 2)
  end

  def test_markdown_in_a_comment_cannot_break_the_table_link_elsewhere_or_read_as_an_escape
    body = 'a | b [x](https://evil.example) <img src=x> @bob `c` C:\\new **bold**'
    row = rows(describe(packet(issue_comments: [issue_comment(1, 'ann', body)]))).first

    assert_includes row, '[“a \\| b x \\<img src\\=x\\> \\@bob \\`c\\` C\\:∖new \\*\\*bold\\*\\*”]'
    assert_equal 3, row.scan(/(?<!\\) \| /).size
    refute_includes row, 'evil.example'
  end

  def test_a_long_agent_reply_shows_only_its_opening_words
    words = (1..20).map { |number| "word#{number}" }
    rendered = describe(packet(inline_comments: [inline(1, 'ann', 'Why?'),
                                                 inline(2, 'ann', "#{IDENTITY}\n\n#{words.join(' ')}")]))

    assert_equal [["[“#{words.first(12).join(' ')}…”](#{URL}#discussion_r2)"]], columns(rendered, 2)
  end

  def test_a_comment_without_prose_is_named
    quoted = "> an earlier point\n\n```suggestion\nfix\n```\n"
    rendered = describe(packet(issue_comments: [issue_comment(2, 'ann', quoted)]))

    assert_includes rendered, "[Code or quoted text only](#{URL}#issuecomment-2)"
  end

  def test_a_code_span_that_opens_a_line_does_not_hide_the_rest_of_the_comment
    rendered = describe(packet(issue_comments: [issue_comment(1, 'ann', "```run``` fails here\nand also there")]))

    assert_includes rendered, '[“\\`\\`\\`run\\`\\`\\` fails here and also there”]'
  end

  def test_only_the_first_twenty_are_shown_and_the_rest_are_counted
    comments = (1..23).map { |id| issue_comment(id, 'ann', "Note #{id}.") }
    rendered = describe(packet(issue_comments: comments))

    assert_equal 20, rows(rendered).size
    assert_includes rendered, "\n\n_3 more not shown; open comments come first._\n\n<!-- /shaka:human-comments -->"
  end

  private

  def answered(reply)
    describe(packet(inline_comments: [inline(1, 'ann', 'more concise', resolved: true),
                                      inline(2, 'ann', reply, resolved: true)]))
  end
end

# The list replaces itself on a new read, stays without one, and refuses a read it cannot place.
class PublicationHumanCommentsSourceTest < Minitest::Test
  include HumanCommentsFixture

  SECTION = { 'heading' => 'What changed', 'body' => 'The parser.' }.freeze

  def test_the_list_follows_the_maintainer_s_open_decisions_and_leads_the_agent_s_sections
    rendered = describe(packet(issue_comments: [issue_comment(1, 'ann', 'A note.')]), 'decisions' => ['Which base?'],
                                                                                      'sections' => [SECTION])
    list = rendered.index("<!-- shaka:human-comments -->\n## Human comments")

    assert_operator rendered.index('## Decisions to make'), :<, list
    assert_operator list, :<, rendered.index('## What changed')
  end

  def test_a_new_read_without_human_comments_removes_the_section
    earlier = pull(body: published(issue_comment(2, 'ann', 'An earlier note.')))

    refute_includes describe(packet(issue_comments: [issue_comment(1, 'ann', REPLY)]), pull: earlier),
                    'Human comments'
  end

  def test_without_a_new_read_the_published_list_stays
    body = published(issue_comment(2, 'ann', 'An earlier note.'))

    assert_includes describe(nil, pull: pull(body:)),
                    body[%r{<!-- shaka:human-comments -->.*An earlier note.*<!-- /shaka:human-comments -->}m]
  end

  def test_a_carried_list_says_when_the_pull_request_has_moved_past_its_read
    body = published(issue_comment(2, 'ann', 'An earlier note.'))
    note = "\n\n_These comments were read at `ccccccc`; the pull request is now at `ddddddd`._\n\n"

    assert_includes describe(nil, pull: moved(body)), "<!-- /shaka:human-comments -->#{note}"
    refute_includes describe(nil, pull: pull(body:)), 'the pull request is now at'
  end

  def test_the_moved_note_is_written_once_however_often_the_list_is_carried
    again = wrap(describe(nil, pull: moved(published(issue_comment(2, 'ann', 'An earlier note.')))))

    assert_equal 1, describe(nil, pull: moved(again)).scan('the pull request is now at').size
  end

  def test_a_fork_s_published_list_is_not_carried_because_its_author_can_edit_the_body
    refute_includes describe(nil, pull: pull(body: published(issue_comment(2, 'ann', 'A note.')), fork: true)),
                    'Human comments'
  end

  def test_comments_read_at_another_head_or_on_another_pull_request_are_refused
    stale = assert_raises(Shaka::Error) { describe(packet.merge('head' => 'd' * 40)) }
    other = issue_comment(1, 'ann', 'A note.').merge('url' => 'https://github.com/owner/repo/pull/8#issuecomment-1')
    foreign = assert_raises(Shaka::Error) { describe(packet(issue_comments: [other])) }

    assert_includes stale.message, 'Run `shaka comments` for that head'
    assert_includes foreign.message, 'outside this pull request'
  end

  def test_a_file_that_is_not_a_comments_result_is_refused
    assert_includes assert_raises(Shaka::Error) { describe([]) }.message, 'shaka comments --head SHA'
    assert_includes assert_raises(Shaka::Error) { describe(packet.except('inline_comments')) }.message,
                    'inline_comments'
  end

  def test_a_walkthrough_may_still_use_the_heading
    walkthrough = { 'identity' => PublicationRegressionTest::IDENTITY, 'summary' => 'A summary.', 'head' => HEAD,
                    'sections' => [{ 'heading' => 'Human comments', 'body' => 'Ann asked for a rewrite.' }] }

    assert_includes Shaka::Publication.walkthrough(walkthrough), "## Human comments\n\nAnn asked for a rewrite."
  end

  def test_a_hand_written_section_is_refused
    error = assert_raises(Shaka::Error) do
      describe(nil, 'sections' => [{ 'heading' => 'human comments', 'body' => 'Ann asked for a rewrite.' }])
    end

    assert_includes error.message, '--comments'
  end
end
