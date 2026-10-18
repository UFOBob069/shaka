# Review process study: shakacode/shaka PRs, 2026-09-19 to 2026-10-17

*An AI agent wrote this report: Claude Code running Claude Opus 5.5, on
2026-10-17. The maintainer asked it to study the review comments on this
repository's pull requests (PRs) and compare them with current guidance for
Claude code review. The agent collected the data, wrote the scripts, and drafted
the text. Codex and a fresh Claude session reviewed it before publication.*

All sources are public PR data, the repository's workflow and prompts, the
maintainer's local Shaka timing logs, and Anthropic's public documentation.

## Main results

- Two local reviewers beat one. Codex reported 37 of the 102 defects that local
  review found, defects Claude did not report. 35 are recorded as fixed. Codex
  costs about $0.09 a run.
- A third reviewer added little. DeepSeek Flash, run after Claude and Codex on 10
  PRs, found one new real bug and one new docs risk. Everything else was a nit, a
  duplicate, or disproved.
- The reviewers usually run in parallel. In the timing log for 2026-10-13 to
  2026-10-18 (UTC), runs overlapped on 106 of 110 commits that had two
  reviewers. A review takes a median of 43 seconds; local validation takes 5.5
  minutes.
- The hosted Claude review found nothing on 86% of runs after local review.
- Agents wrote about 97% of PR discussion. Shaka's own review comments are 30%
  of it.

## Data and limits

- 368 PRs were created in the window. 350 are analysed; Dependabot PRs are excluded.
- Each PR's comments, reviews, and review threads were read through GraphQL, up to
  100 per connection. PRs #268, #269, #284 and #286 exceed that limit, so their
  counts are partial.
- Local review data comes from the published `Local Adversarial Review` comments:
  their execution tables and `Finding details` lines. Findings are deduplicated by
  PR, class, and title. Classes are the reviewer's.
- Dispositions such as "fixed" and "dismissed" are the ones the implementing agent
  recorded. Nobody checked separately whether each finding was real.
- Hosted thread outcomes are a keyword heuristic over the reply text. Treat them as
  approximate.
- Hosted Claude review cost is UNKNOWN: it runs on an OAuth token with no metering
  in the data. Anthropic's published $15–25 per review applies to its managed
  Code Review product, not to this action.

## What goes into a PR

- About 21.5M characters of discussion plus 5.9M of PR descriptions: roughly 6.9M
  tokens. How often agents read all of it was not measured.
- A median PR carries 37.6K characters of discussion (p90 139K) and a
  12.7K-character description.
- The median PR has 10 posts (p90 44).

| Source | Posts | Characters | Share of discussion |
| --- | ---: | ---: | ---: |
| Shaka local-review publications (`local-review`, `local-adversarial-review`) | 477 | 6.36M | 30% |
| Other agent posts from the maintainer account (walkthroughs, evidence, dispositions) | ~3,300 | ~8M | ~37% |
| CodeRabbit (summary, review bodies, inline) | 638 | 3.10M | 14% |
| Hosted Claude review (top-level reports + inline) | 1,728 | 2.45M | 11% |
| Codex connector (review bodies, inline, top-level) | 1,177 | 0.85M | 4% |
| Text clearly written by humans | n/a | ≈ 0.6M | ≈ 3% |

- Agents wrote almost all of this text.
- Shaka's own review publications, at 30%, are the largest single kind of post.
  The mixed group of other agent posts is larger in total.
- Hosted Claude review is 11%.

## Hosted Claude review (`.github/workflows/claude-code-review.yml`)

- It runs on `opened, synchronize, ready_for_review, reopened` and posts a new
  report every run.
  - That came to 1,000 reports on 343 PRs.
  - Median 2 per PR, p90 6, max 32.
- Its prompt is the action's generic "quality, bugs, security, performance" example.
  - It has no list of things not to flag.
  - It has no severity scale and no repository criteria.
- Attested runs (from 2026-10-14, after #507): 95 of 111 report zero findings (86%).
  - A zero-finding report has a median of 658 characters.
  - These PRs had already passed local review, which is a likely reason. The
    study did not measure the cause.
- Inline threads: 728 in total.
  - About 50% got a "fixed"-style reply.
  - About 24% were declined.
  - 9% got no reply.

## Local adversarial review (the ledger)

- The ledger covers 147 PRs and 374 review loops.
- It records 884 reviewer runs, each numbered as its own round. Codex and Claude
  usually review the same commit together. Some commits had only one of them:
  Codex has 30 more runs than Claude.

| Reviewer | Runs | Runs with zero findings | Est. cost per run |
| --- | ---: | ---: | ---: |
| openai/codex | 452 | 86% | ~$0.09 (n=34) |
| anthropic/claude | 422 | 15% | ~$0.25 (n=33) |
| deepseek/openrouter (trial runs in shared ledgers) | 10 | 30% | UNKNOWN |

Unique findings: 792.

| Reported by | Findings | Defects | Risks | Nits | Recorded fixed | Recorded dismissed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Claude only | 719 | 43 | 336 | 340 | 212 (38 defects, 174 risks) | 158 |
| Codex only | 41 | 37 | 3 | 1 | 37 | 1 |
| Both | 27 | 22 | 3 | 2 | 25 | 0 |
| DeepSeek (trial runs in shared ledgers) | 5 | 0 | 3 | 2 | 0 | 2 |

- Codex is precise: almost every finding is a defect recorded as fixed.
- Claude has more findings recorded as fixed: 212, against 37 for Codex.
- 47% of Claude's findings are nits, and 22% are dismissed. Each one still costs a
  triage-and-record step.

What Codex adds over Claude alone:

- Of 102 defects, Codex alone reported 37 (36%). Both reported 22, and Claude
  alone reported 43.
- 35 of the 37 Codex-only defects are recorded as fixed.
- Two related PRs share the same pair of defects. Counting each once leaves 35
  distinct Codex-only defects, spread across 27 of the 147 PRs.
- Neither reviewer sees the other's findings for the same commit. Shaka records a
  commit's findings only after every reviewer of that commit has finished, so no
  review prompt can include them. The runs usually overlap as well: 106 of 110
  times in the timing window. In 27 of the 31 Codex-only findings of any class with a recorded commit,
  Claude reviewed that same commit and did not report it.
- Examples: PATH and arguments read in reverse order (#453), cleanup that could
  delete a user's file (#611), and two different binary files compared as equal
  (#539).
- The ledger cannot show whether Claude would have caught a defect in a later
  round if Codex had not caught it first.
- Codex costs about $0.09 per run, roughly $40 over the four weeks.

Timing, from the helper call log for 2026-10-13 to 2026-10-18 UTC (14,124
calls). This window is shorter than the four-week study and runs one day past it:

- Shaka runs each reviewer with its own `review run`. The agent starts them
  together on one ledger, so they normally overlap: 106 of 110 commits with two
  reviewers had overlapping runs.
- `review run`: median 43 seconds, p90 94 seconds.
- Local validation (`evidence run validate`): median 5.5 minutes, p90 23 minutes.
- The log records each call's start, command, exit code, and duration. It has no
  PR or task identity, so it cannot give the end-to-end time of one PR.

## DeepSeek trial

The maintainer ran DeepSeek Flash (`deepseek/deepseek-v4.1-flash` through
OpenRouter, low effort, diff only, no tools) as an extra reviewer. It ran on
commits that Claude and Codex had already reviewed, to see what it would add.

- 12 attempts with a published outcome, on 10 PRs: #250, #409, #429, #453, #493,
  #511, #512, #515, #516, and #518.
- 3 attempts failed and 9 completed.
  - Two timed out at 300 seconds: #409, and the first attempt on #512.
  - One spent its whole 65,536-token output allowance on reasoning and returned
    no report: the second attempt on #453.
- These counts come from each trial's own published report. The ledger tables
  above include only the 10 DeepSeek runs written into shared Claude and Codex
  ledgers, so their DeepSeek rows are a subset and do not show the #518 defect.
- Completed reviews took 72 to 595 seconds and cost $0.001 to $0.07 each, as
  OpenRouter reported.

| Outcome of completed DeepSeek reviews | Count | Where |
| --- | ---: | --- |
| New confirmed defect | 1 | #518: a saved review history with `earlier_findings: null` raised a raw `NoMethodError`. Only hand-edited or corrupted files hit it; files Shaka writes were unaffected. Fixed before merge. |
| New confirmed risk | 1 | #515: `docs/settings.md` dropped a warning that other hosts' chat links can have different access rules. The warning is back in the current docs. |
| No findings | 1 | #429 |
| Nits, duplicates of Claude or Codex, or disproved concerns | 6 | #250, #453 (first attempt), #493, #511, #512 (600-second rerun), #516 |

- Neither DeepSeek-only item would have reached users as a failure: one needed a
  malformed file, and the other was missing docs wording.
- DeepSeek added little that Claude and Codex had not already caught.
- It is cheap, but slow, and fails often enough to need a fallback.

## Current Anthropic guidance (primary sources, checked 2026-10-17)

- The code-review plugin flags only high-signal issues.
  - That means code that won't compile or parse, definitely wrong output, or a
    `CLAUDE.md` rule it can quote.
  - A separate agent validates each issue, and unvalidated ones are dropped.
  - Its list of things not to flag: pre-existing issues, linter territory,
    general quality or test coverage, input-dependent speculation, and
    subjective nits.
  - It also says, "If you are not certain an issue is real, do not flag it."
  - <https://github.com/anthropics/claude-code/blob/main/plugins/code-review/commands/code-review.md>
- Anthropic's own repository runs the action on `opened` only and skips forks.
  The plugin stops if Claude has already commented on the PR.
  <https://github.com/anthropics/claude-code-action/blob/main/.github/workflows/claude-review.yml>
- The managed Code Review product re-reviews only what changed since the last
  review and posts fewer nits.
  - Its `REVIEW.md` supports a nit cap and skip rules.
  - The action does not read `REVIEW.md`.
  - <https://code.claude.com/docs/en/code-review-pull-requests>,
    <https://code.claude.com/docs/en/code-review-customize>
- `use_sticky_comment` keeps a single comment. Here it would break the #507
  attestation check, which looks for a new comment created during the run.
  <https://github.com/anthropics/claude-code-action/blob/main/action.yml>
- Anthropic reports that fewer than 1% of findings were marked incorrect for the
  managed product. Nothing comparable is published for the action.
  <https://claude.com/blog/code-review>

## Findings

### 1. The local Claude reviewer is noisy, but it carries most of the fixes

- **Observed:** 340 nits and 158 dismissals among 719 Claude-only findings.
  Codex: 1 nit and 1 dismissal among 41.
- **Evidence:** the ledger table above.
- **Proposed change:** in `.agents/shaka/review-prompt.md`, the repository prompt
  rather than the packaged one:
  - adopt the plugin's don't-flag list;
  - say "omit nits unless asked", or cap them at 3;
  - require a concrete triggering state for every risk.

  Then measure for two weeks before touching the packaged prompt.
- **Expected benefit:** about 500 fewer triage-and-record entries per 4 weeks.
  Time saved per entry is UNKNOWN.
- **Guarantee at risk:** the 174 Claude-only risks recorded as fixed.
  Tightening the risk rule could lose some of them, so start with nits only.
- **Not proposed:** dropping Codex. It found 35 distinct defects that Claude did
  not report. For the 31 Codex-only findings of any class with a recorded
  commit, Claude reviewed that same commit in 27. Codex costs about $0.09 a run.
- **Maintenance:** a few prompt lines.

### 2. The hosted Claude review adds few findings after local review, and its prompt goes against Anthropic's guidance

- **Observed:** 86% of attested runs report zero findings. It runs on every push.
  The prompt is the generic example.
- **Proposed change:** replace the prompt with a high-signal version: a don't-flag
  list, plus the AGENTS.md review criteria by reference. Keep the triggers for now.
  - [shakacode/shaka#640](https://github.com/shakacode/shaka/pull/640) takes this
    up. A PR that already has a published Shaka local review gets the short pass;
    a PR from someone not using Shaka gets the full review.
  - Narrowing triggers to `opened`/`ready_for_review` needs a Shaka change first.
    `PrWatch::ReviewGate#review_jobs_terminal?`
    (`skills/shaka/lib/shaka/pr_watch/review_gate.rb`) treats a missing
    `claude-review` check on the current head as not terminal, so `pr watch` would
    wait.
- **Expected benefit:** fewer, shorter reports. The cost saving is UNKNOWN because
  usage is unmetered.
- **Guarantee kept:** this is the one Claude review that runs on GitHub, outside
  the session that wrote the code. Its value may be independence more than
  findings, which argues for a cheaper hosted review over removing it.
- **Maintenance:** the prompt, plus a gate change if triggers narrow.

### 3. Shaka's own review publications are the largest single kind of post

- **Observed:**
  - 477 publications came to 6.36M characters. The median loop is near 13K and
    the largest is 59K.
  - Every loop opens a new comment that holds each round's full report, including
    rounds with zero findings.
  - 96 of 97 publications since 2026-10-15 have no `🤖` writer identifier in their
    first four lines. Shaka requires that line on AI-written posts, so the publish
    code should be checked before calling it a defect.
- **Proposed change:** keep the header, findings, and execution table, and replace
  zero-finding round reports with a single line. Then verify the identifier rule.
- **Expected benefit:** roughly half of the publication text, by estimate.
- **Guarantee at risk:** full raw reports on GitHub. Keeping them only in the
  local ledger would need a durable home for the ledger.
- **Maintenance:** a change to the renderer and its tests.

### 4. Three hosted bot reviewers overlap

- **Observed:**
  - CodeRabbit: 3.1M characters, 116 inline threads, about 52 with a fix-style reply.
  - Codex connector: 616 inline threads, about 490 with a fix-style reply.
  - Hosted Claude: see finding 2.
- **Proposed change:** for the maintainer to decide. Either turn off CodeRabbit's
  summary and walkthrough in its repository configuration, or drop CodeRabbit,
  since the Codex connector covers similar ground with more fixes.
- **Expected benefit:** up to 14% of discussion text.
- **Maintenance:** none.

### 5. The retrospective procedure can't run this study

- **Observed:**
  - Shaka's retrospective procedure limits analysis to named coding sessions and
    does not read repository history.
  - The AI Hero `retro` companion is also scoped to sessions.
  - This study needed one-off scripts over GitHub data.
- **Proposed change:** a deterministic `shaka review stats` command. It would read
  the published ledger comments and hosted attestation lines for a date range and
  print the tables above.
- **Expected benefit:** a repeatable before/after measurement for findings 1–4.
  Frequency of use is UNKNOWN.
- **Maintenance:** a parser tied to Shaka's own publication format, plus tests.

## Run the same study on your repository

Shaka has no built-in procedure for this yet; finding 5 proposes one. Until then,
ask your agent for it as an ordinary task. This report came from a request like
this one, and the agent wrote its own scripts:

```text
$shaka Study the review comments on this repository's PRs from the last four
weeks. Compare each reviewer's findings and dispositions with what was fixed,
and recommend changes to the review process.
```

In Claude Code, start the prompt with `/shaka` instead of `$shaka`.
