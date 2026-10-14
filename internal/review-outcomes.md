# Preserve review decisions and later outcomes

Design proposal for the remaining work on [issue #395](https://github.com/shakacode/shaka/issues/395).
Retention and assessments have shipped; export and real-use evaluation remain open. [Requirements](requirements.md) owns pilot scope;
issue #395 owns this extension's acceptance checklist.

A maintainer should be able to ask, months after a merge, "which reviewer
recommendation led to this change, and was it a good one?" Today that answer
usually disappears with the temporary directory that held the review ledger.

## What has shipped

[PR #398](https://github.com/shakacode/shaka/pull/398) and
[PR #434](https://github.com/shakacode/shaka/pull/434) delivered the presentation
step. Each reviewed commit gets one comment that opens with the reviewed revision,
the findings needing attention, and coverage limits. Settled findings, original
reports, and run metadata sit under one "Review evidence and history" disclosure.
A finding's disposition is now `open`, `decision_needed`, `fixed`, `dismissed`,
`accepted`, or the legacy `documented`, which renders as Unassessed and stays
visible for a defect or risk.

The retention step below, section 1 of the proposal, has also shipped: `review run`
keeps a copy of each report beside the ledger, warns about a ledger in a temporary
directory, and `review publish` names a report that is missing or changed. One
detail differs from the proposal. A round records its copy by full path and hash,
not by relative path, because every reader of a ledger expects a path it can open;
the hash finds the copy again beside a ledger that has moved.

The issue's presentation checklist has not been rechecked against real review
records since those PRs merged. That check belongs to the real-use evaluation below.

The assessment step now preserves replaced triage in ordered `earlier_findings`
snapshots, records actor/time attribution when supplied, and appends later judgments
through `review assess`. The current comment exposes action and disagreement while
keeping settled chains in history. Actors are transcribed, not authenticated.
[Assessment instructions](../skills/shaka/references/review-assessments.md) describe
use; the proposal below preserves the accepted design and its alternatives.

Compatibility differs at the old publication boundary: version 2 ledger writers
refuse version 3, but version 2 publishers can omit its assessments. Use current
Shaka for reading and publication. Current readers reject newer formats before
reading reports or publishing; released older publishers cannot gain that check
through this change. The retained ledger still contains the judgments. Acceptance of this released-publisher\nlimitation was accepted by the maintainer for PR #518. Public triage history\nnow projects supported fields and marks omitted metadata; complete legacy snapshots\nstay private in the ledger.

## Inventory before retention and assessments

Inspected revision: `64cf06040e6e0f609079327fa6b2c225a2359e15`. Paths are relative
to `skills/shaka/lib/shaka/local_review/`.

| Question from the issue | Kept today | Missing |
| --- | --- | --- |
| What did the reviewer claim? | The verbatim report, at a path the round names. `runner.rb` creates it in the system temporary directory. | The report is gone once that directory is cleaned. The ledger keeps the path, not the content. |
| Which reviewers reported it? | `ledger_batch.rb` maps each reviewer's own finding number to one shared finding ID. | Two different remedies for one problem share that ID. |
| What did the owner decide, and why? | `finding.rb` keeps the disposition, a note, and for `accepted` the maintainer's decision. | Who recorded it and when. `record!` in `ledger.rb` replaces a batch's findings, so an earlier decision is overwritten. |
| What changed? | A `fixed` finding names its fix commit, and `triage.rb` flags a finding that returns after its fix. | Whether the fix followed the recommendation, deviated from it, or was later reverted. |
| Was the recommendation right? | Nothing. `fixed` means a commit was named. | Any later judgment of the problem, the remedy, or the implementation. |
| Does anyone need to act now? | `attention.rb` and `summary.rb` keep an open or unassessed defect visible through a clean later round. | A settled finding cannot be reopened by later evidence without rewriting its disposition. |
| Can the record be read later? | The ledger is JSON outside the checkout, written under a file lock. | No format version. The [local review guide](../skills/shaka/references/local-review.md#run-the-review-loop-with-a-ledger) suggests `mktemp -d` for its location. |

The maintainer has observed the retention gap: review ledgers kept in a session's
temporary directory were gone when tasks resumed days later. No public record of
those losses exists. No real
example of a harmful accepted recommendation has been recorded yet, so how often
that happens is unknown.

## Proposal

Add three things to the existing ledger. Keep `rounds` and `findings` exactly as
they are, so merge evidence, the round cap, and publication keep reading the same
fields.

### 1. Keep the ledger and its reports in a durable place

The caller keeps choosing the ledger path, one directory per task. The guide's
example changes from `mktemp -d` to a directory under
`~/.local/state/shaka/reviews/`, named for the task when the loop starts, such as
`OWNER-REPO-395-a1b2`. `review run` reports a warning in its result when the
ledger sits under the system temporary directory. When a round completes, the
helper copies its report to `reports/SHA256.md` beside the ledger before
appending the round, and the round records that relative path and hash. A failed
copy appends no round.

The helper does not pick the path. A path derived from the branch name would hand
a later task the ledger of an earlier one that reused the name, and commit
ancestry cannot tell the two apart after a merge. A pull request number would
separate them, but the loop starts before the pull request exists.

Publication and export read the bundled copy. A missing or altered report is
reported by name as unavailable; a hash cannot restore it, and nothing guesses
its content. The guide's example creates the directory private to the user (mode 0700). Nothing expires it
or collects it in the background; the user deletes it deliberately.

Not proposed: bundling Git objects for commits that were never pushed. The
comment already marks such a commit "not on GitHub", and that is honest enough
until a real reassessment needs the missing code.

A round without a hash is unbundled: an unversioned ledger has only such rounds,
and a helper released before this work can still append one. Readers report that
round's report as available only while its original path still holds it.

### 2. Say who triaged, and stop overwriting an earlier triage

`review record` stamps each finding it records with `recorded_at` and accepts an
optional `by` with a name and role, in the form `assess` uses below. An absent
`by` stays unknown. The stamp lives on the finding, so a finding written by a
helper released before this work simply has none.

When `review record` replaces a batch's findings, the helper first moves the
previous findings, with their stamps, into that round's `earlier_findings` list. The
current view reads `findings` as before. History and export can show what the
owner believed first and when. Recording the same findings again changes nothing.

### 3. Record a later assessment without editing the finding

`shaka review assess --ledger PATH --content-file FILE` appends one entry to a
top-level `assessments` list, under the lock `record` already uses.

```json
{
  "id": "A1",
  "finding": "F1",
  "recommendation": { "head": "FULL_SHA_A", "reviewer": "openai/codex", "reported_as": "2" },
  "problem": "refuted",
  "remedy": "harmful",
  "implementation": "correct",
  "action": { "taken": "as_proposed", "commits": ["FULL_SHA_B"], "attribution": "direct" },
  "attention": "action_required",
  "by": { "name": "example-maintainer", "role": "maintainer" },
  "revision": "FULL_SHA_B",
  "observed_at": "2026-09-04",
  "rationale": "The idempotency guard already prevents duplicate writes; removing the retry fails after a transient error.",
  "evidence": ["https://github.com/OWNER/REPO/pull/12#issuecomment-1"],
  "supersedes": []
}
```

| Field | Values | Answers |
| --- | --- | --- |
| `problem` | `confirmed`, `refuted`, `uncertain`, `disputed` | Was the alleged problem real? |
| `remedy` | `supported`, `unnecessary`, `incorrect`, `harmful`, `excessive`, `inconclusive` | Was the proposed change appropriate? |
| `implementation` | `correct`, `defective`, `uncertain` | Did the change realize the remedy? |
| `action.taken` | `not_attempted`, `as_proposed`, `differently`, `partially`, `reverted`, `replaced` | What actually changed, in which commits? |
| `action.attribution` | `direct`, `uncertain` | Did this recommendation lead to those commits? |
| `attention` | `action_required`, `decision_required`, `none` | Does anyone need to act now? |

An entry needs `id`, `finding`, `by`, `rationale`, and at least one of the six
fields in the table. Every other field may be absent, and an absent judgment
means unknown, never positive or negative. `recommendation` narrows the entry to
one reviewer's remedy when two reviewers agreed on the problem and proposed
different changes. The reviewed commit, the reviewer, and that reviewer's own
finding number already identify one remedy in one report, because the ledger
allows each reviewer one report per commit. No new identifier is introduced. The commit matters: the same reviewer can report the same finding
under the same number on a later commit with a different remedy.

Rules the helper would enforce:

- Entries are appended, never edited. A correction is a new entry whose
  `supersedes` lists the earlier entries it replaces, which stay in the list.
- Repeating an identical entry is a no-op. A different entry reusing an `id` is refused.
- `finding`, `recommendation`, and `supersedes` must name records in this ledger.
  While an assessment that no entry has superseded names a finding, `review record`
  refuses a triage that drops that finding ID or moves the assessed reviewer
  number to another finding. To merge or re-collate such a finding, first append
  an assessment that supersedes those entries and names the surviving finding. A
  reference that no longer resolves, as after a triage by an older helper, is
  reported as unavailable.
- `revision` is the commit the judgment was observed at. It may differ from the
  reviewed commit in `recommendation` and from the commits in `action`.
- The helper stamps `recorded_at`. `observed_at` is the caller's and may be earlier.
- Two entries conflict when neither is superseded, both name the same finding,
  and they give different values for the same field. `problem` judges the
  finding, so it is compared across every entry for that finding. An entry that
  names no recommendation speaks for the whole finding, so its other fields are
  compared with every entry too. Two entries naming different recommendations
  are not compared on those fields. Who wrote them does not matter. Conflicting
  entries both stay, the helper picks no winner, and the current view shows the
  finding as needing a decision until one entry lists both in `supersedes`.
- A superseding entry replaces the whole earlier entry in the current view, so it
  restates each judgment it keeps.
- `evidence` holds `https` links and full commit SHAs only. `id` follows the
  finding ID format and `by.role` is one of a fixed list. Every other string,
  including `rationale` and `by.name`, is one line of untrusted text rendered
  through the escaping that finding notes use.

The helper cannot verify who is speaking. `by` is the recording agent's
transcription, as the `accepted` disposition's `decision` field is today.

### How the comment changes

An assessment whose `attention` is not `none` adds its finding to the visible
attention table of the latest reviewed commit's comment, with the remedy
judgment and the rationale. Once an entry with `attention: none` supersedes it,
the chain moves under Finding details in the history disclosure. The closing
attestation line never changes, so merge evidence for a merged PR reads the same
before and after a reassessment. An assessment is displayed; it adds no merge
gate, on an open PR or a merged one. Republishing an unchanged comment still
writes nothing.

### Compatibility

Each PR that changes the format raises the version on its first write: retention
writes `version: 2`, assessments write `version: 3`. A helper refuses a version
above the one it knows, so a retention-only helper never rewrites a ledger that
holds assessments. A ledger without a version reads as before: `fixed` means a
named commit, `documented` stays ambiguous, and no actor, time, or outcome is
inferred.

Helpers released before this work cannot be made to refuse. One of them writing a
newer ledger keeps keys it does not know, at the top level and inside each round,
because `record!` and `triaged` merge into the parsed data. It will still replace
a triage without saving the earlier one, and the findings it writes carry no
stamp. That loss is limited to the batch it records, and it is the behavior every
ledger has today.
The first draft required a tested refusal by older writers; this proposal drops
that requirement because no change here can add a check to a released helper.

## Why not something smaller or larger

**Smaller: write the later assessment into the finding's note or a PR comment.**
This costs nothing to build. The note is overwritten by the next record, a PR
comment can be edited or deleted, and neither can be exported with the
recommendation it judges. It suits a single discussion, not a record meant for
evaluation.

**Middle: append attributed free-text assessments, with no typed judgments.**
This keeps history and attribution with about half the validation. It cannot
separate "the problem was real" from "the fix was right", which is the
distinction the issue exists to make, and an export would need a person to
classify every entry again.

**Larger: turn every decision into an event with its own recommendation and run
identifiers.** The first draft of this design proposed that. It duplicates what
rounds and findings already record and needs a projection to rebuild the current
view. The proposal above adds one list and leaves the working model alone.

Estimated cost of the proposal: one small class to validate an assessment, one
command, a copy step in the runner, and an `earlier_findings` list, each with failure
and concurrency tests. The benefit is unproven until a real reconsidered
recommendation is recorded; the retention step has observed value by itself.

## Synthetic chains the tests must cover

Every identity, revision, date, and outcome below is invented. None describes a
real PR.

**S1: an accepted removal later shown harmful.** At A, a reviewer reports
duplicate writes and recommends removing a retry. The owner records `fixed` with
commit B. Validation passes at B and a second review finds nothing. Later a
maintainer shows that an idempotency guard already prevented duplicates and that
B fails after a transient error. Assessment A1 (above) records problem refuted,
remedy harmful, implementation correct, action required. Commit C restores the
retry. A2 lists A1 in `supersedes`, restates problem refuted, remedy harmful, and
implementation correct, sets `action.taken: reverted` with C, and sets
`attention: none`. The comment shows the regression while A1 stands and collapses
the chain after A2. The owner's `fixed` record and A1 are both still readable.

| Case | What the record must distinguish |
| --- | --- |
| S2: real problem, excessive remedy | `problem: confirmed`, `remedy: excessive`, `implementation: correct` |
| S3: good remedy, bad implementation | `remedy: supported`, `implementation: defective`; a later entry supersedes it, restates `remedy: supported`, and names the corrective commit |
| S4: wrong recommendation declined | Finding `dismissed`; `problem: refuted`, `action.taken: not_attempted`, no commit invented |
| S5: two assessments disagree | Both entries kept; the view asks for a decision until one entry lists both in `supersedes` |
| S6: requirements changed | A later entry supersedes the first, restates `remedy: supported`, and records `replaced` and why; the first stays readable and nothing calls it harmful |

Each case also runs with a missing report and with `attribution: uncertain`.
Retried and concurrent `assess` calls must neither lose nor duplicate an entry.

## Export, later

One JSON document per ledger: an export version, the ledger's base commit, the
rounds with their bundled report text, the findings with any earlier triage,
and the assessments in recorded order. The export generates no timestamps or
identifiers, so repeating it yields the same bytes. Each assessment keeps its
`recorded_at`, which lets a reader separate what was known at review time from
what was learned later. Unavailable reports are marked, not dropped. Report text
is private until published, so the export stays private by default; a public
export omits report text, local paths, and private links and marks each omission.
No numeric
reward, training upload, or provider integration is part of this work.

## Delivery

1. **Retention.** The durable-location guidance and warning, bundled reports, and
   unavailable-report reporting. Useful alone, and it fixes an observed loss.
2. **Assessments.** The finding stamps, the `earlier_findings` list, `review assess`, the comment change,
   compatibility, and chains S1 through S6 as tests.
3. **Export.** The deterministic document and the same chains as export fixtures.
4. **Real-use evaluation, on the issue.** Recheck the presentation checklist on
   real records and record a reconsidered recommendation when one genuinely occurs.

## Decisions

The maintainer accepted all three recommendations on 2026-10-11 (UTC), in the
task chat that produced this proposal; the proposal's pull request records it.

1. **Judgments are typed,** as proposed. Attributed free text was the fallback.
2. **The caller chooses where a ledger lives,** guided to a per-task directory
   under `~/.local/state/shaka/reviews/`, with a warning for a temporary path.
   The official install directory, `~/.agents/shaka/`, was considered and
   rejected: it is a clone of the public repository that `shaka install` updates,
   so private reports there would sit as untracked files in a public checkout and
   would be lost with a reinstall. A helper-chosen path keyed by pull request
   number stays possible later.
3. **Retention ships first,** as its own PR, because its value does not depend on
   the assessment design.
