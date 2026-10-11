# Invoke a reviewer locally

First [select a reviewer](review.md#choose-a-local-reviewer) using trusted policy.
Use this reference for CLI execution and report validation.

## Reviewer model and effort

Repository `model` and `effort` settings come from the reviewer's entry in the
trusted default-branch configuration supplied with `--criteria-ref`. Candidate
PR settings cannot select their own reviewer. Without that ref, repository
settings are not applied. Explicit `--model` or `--effort` arguments override the
configured value for that review.

When no model or effort is specified, the reviewer uses its CLI defaults. Codex
runs with user configuration disabled, so personal Codex settings do not select
the review model. Pin a model when predictable cost matters.

`shaka doctor` checks configured reviewer settings. `shaka review run` checks
the requested settings before launch, and adds a **Reviewer settings** notice to the published local review when
settings need attention. Relay that notice to the maintainer.

The catalog in `skills/shaka/lib/shaka/reviewer_settings.rb` defines known names
for spelling checks, not account availability:

- Likely spelling mistakes and unknown models produce warnings and still run.
  Newer model names can therefore run before the catalog knows them.
- Known models preserve the configured choice without recommending a replacement.
- Unknown Codex or Grok effort names produce warnings and still run. Effort
  names use lowercase, such as `medium` or `xhigh`.
- Shaka accepts only `low`, `medium`, `high`, `xhigh`, and `max` for Claude
  effort. Another value fails doctor and stops review before the CLI starts.

The spelling check recognizes a one-letter substitution or an adjacent-character
swap in a same-length name. A digit substitution is treated as an unknown name,
not a spelling mistake. Both warnings allow execution.

Shaka classifies the known Codex ChatGPT-account refusal from Codex JSON error records as
`failure_cause: account_model_refused`. HTTP 400 JSON detail wrappers are recognized; other model-access errors and stderr remain ambiguous.
It preserves `requested_model` and `requested_effort` on review outcomes and never retries
with a substitute. A generic invalid model, timeout, or nonzero exit still needs diagnosis.
An account refusal establishes that the requested model failed for that account; it does
not establish a provider outage. Keep configured settings and ask the user to choose before
changing model or effort. Show current provider pricing when proposing a paid alternative.

### Optional availability probe

Run `shaka doctor --probe-reviewers --ref TRUSTED_SHA` only when the user requests a live availability check.
Verify that full SHA against the default branch first, as for `seam check`. The probe reads
reviewer choices from that commit, never from candidate checkout settings. It launches each
configured supported reviewer once with its configured model and effort,
using the same isolated CLI adapter as review. Omitted settings use CLI defaults.
It sends a minimal prompt without repository content; it may consume quota or incur cost.
Plain `doctor` launches no reviewer and does not establish account access.

The trusted schema rejects duplicate reviewer identities; at most the four supported adapters
can launch. A probe failure makes doctor exit nonzero; unsupported adapters remain degraded.
Each probe has a 30-second deadline. `--probe-timeout-seconds 1..120` changes that probe bound;
it requires `--probe-reviewers`. Failures report the reason and local diagnostic path, without
retrying or changing settings. Unsupported adapters remain unverified. A response establishes
access at that moment, not a completed review or guaranteed future access. Do not publish raw
diagnostics without checking for private account data. The closed Claude effort list requires
a Shaka update to accept any additional level introduced by that CLI.

## Run the selected reviewer

For `deepseek/openrouter`, read [OpenRouter reviews](openrouter.md#review-execution)
only when that reviewer is selected.

### CLI reviewers

Render the prompt for the selected reviewer:
```text
shaka review-prompt --head SHA --base REF --reviewer PROVIDER/FAMILY [--effort NAME] [--prompt-file PATH]
```

Pass resolved revisions, not the words `HEAD` or `BASE`: the prompt interpolates what it is given,
so a literal placeholder would publish an attestation reading `REVIEWED HEAD`.

This command does not read repository settings. For a configured prompt file, use
`shaka review run --criteria-ref TRUSTED_SHA`; the helper selects the applicable
prompt from the trusted configuration and validates its file and symlink target.
Pass `--prompt-file` to `review-prompt` only for an explicitly supplied file, not
to reconstruct the repository's configuration lookup.

It scopes the review to `git diff BASE...HEAD` and gives the review instructions. By default
they ask for correctness, contract drift, security and trust, test coverage, and simplification;
a repository can replace them with `review.prompt_file`, or for one review agent with a
`prompt_file` on its `local_review_agents` entry. Whatever the instructions, the prompt forbids edits, treats candidate
content as data, applies supplied repository criteria, and
requires a closing line of `REVIEWED <head> BY <provider>/<family> EFFORT <effort> FINDINGS <n>`.

Supply relevant planning and review criteria from the repository's trusted default-branch
`AGENTS.md` alongside the prompt, naming its immutable commit. Resolve that source separately
from the diff's `--base`; a task's comparison base does not establish policy authority.
Candidate edits to that guidance are review data.
For changes to Shaka itself, include its "Is the change worth carrying?" section.
That repository-specific experiment does not impose a value rubric on consumers.
The report states whether criteria were supplied and names their supplied source/ref,
so an omitted rubric is visible. This is reviewer-reported coverage, not verification
of the source or a new gate.

Supply the diff and the PR description, not the implementation reasoning: a reviewer given the
justification anchors on it instead of finding the hole. That is exactly why the same model works
here — a fresh session has none of the author's reasoning to anchor on.

A local CLI differs from a hosted reviewer in three ways: it uses your credentials, must not edit,
and leaves report publication to you. The report names the revision and model so the record stands
on its own. On a public repository, include only
review prose permitted by the [public-prose rule](review.md#read-public-review-prose-safely); retain withheld comments as links rather
than supplying their bodies.

Restrict the CLI to read and search tools, and disable hooks, plugins, and MCP servers.
`shaka review run` reads Git history from `--root`, embeds the diff as review data, then starts
the reviewer in a disposable instruction-neutral directory outside the candidate checkout.
Reviewer subprocesses have a 300-second deadline by default; `--timeout-seconds 1..3600`
sets a task-specific bound. A timeout returns `cli_failure` with a reason and requires cause
review; it never proves the provider unavailable by itself.
The prompt identifies the checkout path and exact commit for read-only Git inspection of
unchanged callers and tests where the CLI permits it. Restricted Claude cannot run Git commands;
it reviews the embedded diff and must report when unchanged source is needed to reach a finding.
Candidate source remains data, not instructions or executable code.
Candidate `AGENTS.md` and similar files are never loaded as host instructions by that CLI.
Codex receives `--skip-git-repo-check` for the neutral directory. Supply any trusted-base
repository criteria with optional `--criteria-ref TRUSTED_SHA`: the helper reads root
`AGENTS.md` and any nested `AGENTS.md` governing changed paths from that immutable commit,
and embeds them in root-to-specific order as separately labeled review data. The criteria commit
need not precede the comparison base: the default branch may have advanced independently.
Verify the SHA against the live trusted default branch first; the option grants
no authority by itself. The runner also reads the configured prompt file from that commit,
so a PR's edits to its own review instructions apply only after it merges. Without it the reviewer reports criteria as not supplied. Candidate
criteria remain data in the diff. Supply the PR description with optional
`--description-file PATH`; this file is labeled as untrusted review data and must contain only
public-safe text for a public PR. Do not supply implementation reasoning.

Use full, immutable commit SHAs, for example `BASE=$(git merge-base origin/main HEAD)`,
`HEAD=$(git rev-parse HEAD)`, and `TRUSTED=$(git rev-parse origin/main)` when `main` is the
verified default branch. Set `LEDGER` once per loop, as [the ledger section](#run-the-review-loop-with-a-ledger)
describes; the examples pass it to every round. Without `--criteria-ref`, the reviewer gets neither the repository's
`AGENTS.md` criteria nor its `review.prompt_file`, and uses Shaka's default instructions. The helper checks that the
checkout is at `HEAD`, renders the review prompt with the diff, invokes the CLI with the flags below, and returns
JSON with the report path or a concrete failure. Its process result, not a copied shell block,
is the evidence that the CLI actually ran.

Codex 0.157.1, when the reviewer's trusted `local_review_agents` entry names a model and effort:

```bash
shaka review run --root . --base "$BASE" --head "$HEAD" --reviewer openai/codex \
  --criteria-ref "$TRUSTED" --ledger "$LEDGER"
```

When the entry names neither:

```bash
shaka review run --root . --base "$BASE" --head "$HEAD" --reviewer openai/codex \
  --criteria-ref "$TRUSTED" --ledger "$LEDGER"
```

With `--criteria-ref`, the helper takes the model and effort from that entry. A named `--model`
or `--effort` replaces the configured one for that review, so add one only when the entry leaves
it out or the task needs a different choice.
When neither names a model, Codex runs its built-in default; see
[reviewer model and effort](https://github.com/shakacode/shaka/blob/main/docs/settings.md#reviewlocal_review_agents)
for choosing a model and effort. Keep the configured choice unless the user selects a different model or effort.

A current-host Task or subagent that selects a Codex model is not this `openai/codex` local
reviewer and cannot replace `codex exec`. It also is not evidence for `--unavailable`.
Use that flag only when `shaka review run` reports `executable_missing`, or after a `cli_failure`
whose local diagnostic establishes a real reviewer outage. A bad argument, setup failure,
dirty worktree, or report-validation failure does not qualify.

The helper runs `codex exec -s read-only --ignore-rules --ignore-user-config
-c skills.include_instructions=false --skip-git-repo-check --json -o REPORT -` from its neutral directory,
adding `-m MODEL` for `--model` and `-c model_reasoning_effort="EFFORT"` for `--effort`. An effort
must be a lowercase level name such as `medium`; without one the report records `EFFORT UNKNOWN`.
`-s read-only` confines it, the ignore flags skip user/project rules and config, and the skills
setting keeps installed skill descriptions out of the reviewer's instructions to prevent
description-based routing to an unrelated installed skill. The report is created outside the checkout.
It does not use `--ephemeral`, so the session remains saved. `--json` reports its thread ID,
and the result's `usage` names that saved session under `CODEX_HOME` (default `~/.codex`);
run `shaka usage --host codex --file USAGE --commit HEAD --contribution review --all-turns`
on it. A missing `usage` means the session file was not found, and review usage stays UNKNOWN.
`codex exec review --base REF` cannot accept the custom review prompt, so the helper uses `exec`.

Claude Code, when the trusted entry names an effort:

```bash
shaka review run --root . --base "$BASE" --head "$HEAD" --reviewer anthropic/claude \
  --criteria-ref "$TRUSTED" --ledger "$LEDGER"
```

When it names none:

```bash
shaka review run --root . --base "$BASE" --head "$HEAD" --reviewer anthropic/claude \
  --effort medium --criteria-ref "$TRUSTED" --ledger "$LEDGER"
```

A current-host Task or subagent that selects a Claude model is not this `anthropic/claude` local
reviewer and cannot replace `claude -p`. It also is not evidence for `--unavailable`.
Apply the same failure-cause check before marking `claude` unavailable.

The helper runs `claude -p --permission-mode plan --permission-prompts none --restricted
--safe-mode --strict-mcp-config --effort EFFORT --output-format json -`. It rejects an error,
empty result, or wrong-head attestation. `-p` prints and exits; JSON holds the review text and
native token counters. Run `shaka usage --host claude-code --file PATH --commit HEAD
--contribution review` on the corresponding Claude session. `--permission-mode plan` with
`--permission-prompts none` withholds edits
and denies anything that would prompt. `--restricted` removes command-running tools.
`--safe-mode` disables project CLAUDE.md, skills, plugins, hooks, and MCP while **keeping
Claude.ai OAuth**. `--strict-mcp-config` with no config drops MCP servers. Do **not** add
`--bare`: that flag skips keychain and OAuth (`Not logged in · Please run /login`) and only
accepts `ANTHROPIC_API_KEY`, so a logged-in Max/claude.ai session looks unavailable.
`--effort` is recorded in the attestation. Pass `--model NAME` to pin the reviewer model;
the helper adds `--model NAME` to that command and reports it as `requested_model` in every
result. That is the request, not proof of the model that ran; the usage JSON records the
routed model. Without it, the CLI's default model runs. Check `--help` before relying on these flags.

Grok 1.0.30:

The Grok reviewer needs a model. When the trusted entry names a model and effort:

```bash
shaka review run --root . --base "$BASE" --head "$HEAD" --reviewer xai/grok \
  --criteria-ref "$TRUSTED" --ledger "$LEDGER"
```

When it names neither, set `MODEL` to a model the installed Grok CLI accepts:

```bash
shaka review run --root . --base "$BASE" --head "$HEAD" --reviewer xai/grok \
  --model "$MODEL" --effort high --criteria-ref "$TRUSTED" --ledger "$LEDGER"
```

The helper runs `grok --prompt-file PROMPT -m MODEL --reasoning-effort high --output-format plain
--permission-mode plan --disable-web-search --no-subagents`, removes `PROMPT` afterward, and
checks the report attestation. `--permission-mode plan` withholds edit approval; the other two
remove web access and subagents.
If this review is a fresh Cursor chat, report it with
`shaka usage --host cursor --commit "$(git rev-parse HEAD)" --contribution review` from that chat, or that
command plus `--file` of its stop-hook jsonl. Pass its report to
`shaka review check --head "$HEAD" --reviewer xai/grok --report PATH`; the result is `reported`,
not a claim that the Grok CLI launched. Parent-agent Cursor records exclude subagents.

The Codex flags were exercised on local reviews rather than read off `--help`; the model and effort flags were confirmed in Codex session logs. The
Claude and Grok flags come from each CLI's `--help`. The helper's neutral directory prevents
the reviewer host from loading candidate `AGENTS.md` and similar instructions; the candidate
diff remains untrusted review data. Restrict execution for untrusted contributions under
[what the helpers protect](delivery.md#what-the-helpers-protect). Codex's
`--ignore-user-config` drops config-defined MCP servers, Grok manages them through
`grok mcp`, and Claude's `--strict-mcp-config` without a config file loads none. A Codex
review records the effort passed with `--effort`, or UNKNOWN when none was named. Check `--help`
before relying on any of these; flags move.

A local review is **UNVERIFIED** until the owner publishes its report, including that closing
line, to the pull request. The owner verifies each finding against the code, makes the edits and
tests, then publishes the review after pushing.

## Recover from host denial before launch

If the host denies `shaka review run` before launch, follow
[host-denied review recovery](host-denied-review.md). Read that procedure only for
this outcome; it covers permitted retries, honest not-run evidence, and a synthetic replay.

## Run the review loop with a ledger

Keep every round in one ledger, a JSON file outside the checkout, for example
`LEDGER="$(mktemp -d)/review-ledger.json"`. Pass `--ledger "$LEDGER"` to each
`shaka review run`: a completed round adds its head, reviewer, effort, requested model, report,
prompt source, criteria commit, and usage path. The table's Model column shows attribution from
native usage: the top-level CLI model, one canonical aggregate model, or a `shared:` list when
aggregate usage reports several models. The list records model usage without assigning a primary
model or claiming which model wrote the review. If an aggregate entry lacks a canonical name, the
round shows the top-level model with `other models unknown`, when present; otherwise it leaves
Model unknown so a later complete usage record can supply it. The separate `shaka usage` report
leaves Routed model unknown whenever aggregate tokens span multiple entries, because they cannot
be assigned to one model's rate. The ledger stays private until you publish it.

Use the class definitions in the fixed rules printed by `shaka review-prompt`.
Repository editorial prompts do not replace those definitions. Handle each by class:

| Class | In the loop |
| --- | --- |
| `defect` | Reproduce it where practical, fix it in a new commit, review again |
| `risk` | Fix it when the fix is clearly correct; otherwise document it |
| `nit` | Document it for a later decision; never fixed in the loop |

After a round with findings, record what became of each one:

```bash
shaka review record --ledger "$LEDGER" --content-file FINDINGS.json
```

```json
{
  "findings": [
    { "id": "F1", "summary": "Exit code is 0 on a failed push", "class": "defect",
      "disposition": "fixed", "commit": "FULL_FIX_SHA" },
    { "id": "F2", "summary": "Rename run_all", "class": "nit", "disposition": "documented",
      "note": "Outside this change" }
  ],
  "model": "gpt-6-sol", "tokens": "41,200"
}
```

Finding notes are published in the comment. Keep every `note` public-safe.

Use these dispositions:

| Disposition | Use when | Published status |
| --- | --- | --- |
| `open` | The agent still has a fix or assessment to complete | Open |
| `decision_needed` | A consequential design choice needs the maintainer | Needs your decision |
| `fixed` | A fix commit exists; publication waits for its review | Fixed, in history |
| `dismissed` | Evidence disproves the finding; explain it in `note` | Dismissed, in history |
| `accepted` | The maintainer explicitly accepts the consequence | Accepted, in history |
| `documented` | Legacy records or optional nits | Unassessed for defects/risks; nits in history |

For `decision_needed`, give the options, tradeoffs, and recommendation in `note`.
Copy the question into the PR description's `decisions` and wait before dependent work.
Use `accepted` after the maintainer chooses, with a public-safe `decision` recording
who chose what and a `note` explaining the consequence. Ruby requires those fields;
the agent verifies the human decision. Explicitly fixed, dismissed, and accepted findings are
resolved for the loop cap. A clean later review does not close an older finding.

To update an earlier batch after a fix or decision, run `review record` with
`--head REVIEWED_SHA` and that batch's complete findings and reviewer mappings.
Republish the ledger to refresh the current summary and collapse older reports.
Keep the same IDs, reporting reviewers, and original reports; recording a disposition
is not a new reviewer finding. For an earlier batch, a fixed disposition names a later
reviewed commit containing the fix; unreviewed revisions are refused. Existing fix references
already checked when the loop advanced remain valid. Omit `--head`
to record the newest batch before the next review.

`fixed` needs the fix commit's full SHA. The helper refuses a
fixed nit, a count that differs from the report's `FINDINGS n`, and a repeated id. Give a
finding the same `id` when a later round raises it again: the comment then flags a finding that
returned after its fix, a sign the fixes are not converging. Give a new finding an id no
earlier round used: the outcome follows each id's latest disposition, so reusing one for a
different problem can hide an unfixed defect. `model`, `tokens`, `cost`, and
`estimate` are optional, as described below, and a top-level `fallback` sets the fallback notice.

`review run` refuses a new head until every round on the last head has its findings recorded.
Another reviewer may join the last reviewed head. It refuses any other head the ledger already
reviewed, a head that lacks the last reviewed head or any recorded fix commit, a fix recorded as the
head it was found in, and a different `--base`; after a rebase, start a new ledger. Publishing
refuses a fix recorded by any round on the last head, because no later round has reviewed it.
The next round's prompt
lists, as review data, every earlier finding's id, class, summary, and latest disposition
(including fixed, open, decision-needed, and closed dispositions), plus the commits since the newest
reviewed head before this one. It asks the reviewer to confirm each fix and to review the full diff fresh.
It leaves out each `note`, so the reviewer does not anchor on the author's reasons.

When several reviewers read each head, as `shaka reviewer` lists them, start them all against
one ledger before recording anything; they can run at the same time. Their rounds on one head
form a batch. While a review runs, the ledger marks it running, and `review record` refuses the
batch until every running review has finished. Record the whole batch in one triage: list each
problem once, and map every reviewer that reported it to that reviewer's own number for it in
`reviewers`, so a problem both found gets one entry and one fix. Put each reviewer's usage under
`usage`, keyed by reviewer. Here Codex's finding 1 and Claude's finding 2 are the same problem:

```json
{
  "findings": [
    { "id": "F1", "summary": "Exit code is 0 on a failed push", "class": "defect",
      "disposition": "fixed", "commit": "FULL_FIX_SHA",
      "reviewers": { "openai/codex": "1", "anthropic/claude": "2" } }
  ],
  "usage": { "openai/codex": { "model": "gpt-6-sol", "tokens": "41,200" } }
}
```

The helper refuses a finding without `reviewers` when the batch has several rounds, one
reviewer's number claimed by two findings, and a count that differs from any reviewer's
`FINDINGS n`. It does not read the numbers inside a report, so match each number to the
report yourself; the checks make each reviewer's findings map one to one by count.
The published comment keeps retained unresolved findings visible and puts settled findings
inside its history. Under each report of a commit several reviewers read, it shows which
of that reviewer's findings became which finding. A solo report has no collation mapping.
Once a batch is recorded, no reviewer can join it. A round whose start checks read a ledger that changed while it ran, other than by
another reviewer of its commit, is refused; run it again.

The trusted `review.local_max_rounds` (default 5) caps the commits reviewed in this ledger; several reviewers of one commit count once.
`review run` refuses the next round with `failure_stage: round_cap` before launching a reviewer.
The ledger records the cap used, and publication uses that value; older ledgers default to 5.
If the cap leaves an unfixed defect, stop before pushing and tell the user. Push only if they
choose to. The comment shows a visible **Loop bound reached** section with unresolved defects,
the rounds they appeared in, returned defects, and a ready task-reassessment prompt.
If the cap prevents review of a last-round fix, stop before pushing and tell the user.
Publication still refuses that fix because no later round reviewed it; reassess the task.

Otherwise, settle open findings and obtain any needed maintainer decisions. Document optional nits. Push, open or adopt the
pull request, then publish right away:

```bash
shaka review publish OWNER/REPO NUMBER --content-file "$LEDGER"
```

## Publish content

The ledger is the content file. Without one, the content JSON lists `rounds`. Copy each
round's `head`, `reviewer`, `report`, `prompt_source`, and `criteria_ref` from its
`shaka review run` result, and add its `findings` in the shape above. Publishing refuses a
round whose findings do not match its report's `FINDINGS n`, so every finding has a disposition.
It also refuses one reviewer reading a commit twice, rounds of one commit listed apart, and a
fix recorded in the commit its round reviewed. A
content file without a ledger gets only these checks: publishing does not read Git history, so
use `--ledger` when fixes must be proven to follow and reach the reviewed head.
Add `model`, `tokens`, and `cost` from native usage; a missing value renders `UNKNOWN`. Leave
`cost` out unless the host reports a priced route. For a subscription session, put the
`USD estimate` that `shaka usage` reports in `estimate` instead: the table marks it `est.` and
the returned loop summary calls it an API-equivalent estimate, never a bill. When `shaka reviewer` did not return `different_provider`, add
`fallback` with its `outcome` and one `attempts` entry per reviewer tried, copying each
`reviewer`, `failure_stage`, and `reason` from its `shaka review run` result. Leave
`attempts` empty when selection tried no other reviewer. The helper replaces each `reason`
from its first absolute or home-directory path onward with `[path]`, so a setup failure does
not publish a local file location.

```json
{
  "rounds": [
    { "head": "SHA", "reviewer": "openai/codex", "report": "/tmp/shaka-review-x.md",
      "prompt_source": "Shaka default", "criteria_ref": "TRUSTED_SHA",
      "model": "gpt-5.5", "tokens": "41,200", "estimate": "$0.17",
      "findings": [
        { "id": "F1", "summary": "Rename run_all", "class": "nit", "disposition": "documented" }
      ] }
  ],
  "fallback": { "outcome": "same_provider", "attempts": [
    { "reviewer": "xai/grok", "failure_stage": "executable_missing", "reason": "grok is not on PATH" }
  ] }
}
```

The helper checks that each report closes with the attestation for its round. Reports are
published verbatim, so before posting it asks GitHub to render the comment and refuses when an
unclosed code fence or a stray disclosure tag in a report would hide the attestation. The
check cannot stop two reports that together imitate a round's layout, for example a reviewer
steered by the PR it reads. The attestation and the summary table stay authoritative, because
the helper writes both itself. It posts one `Local Adversarial Review` comment per reviewed
commit, in ledger order. Each opens with the reviewed revision, a compact table of
findings needing attention, and coverage limits. Each finding lists every reviewer
that reported its ID. Explicitly fixed, dismissed, and accepted findings move into
evidence history; legacy documented defects and risks remain visibly unassessed.

The closed evidence disclosure preserves all disposition explanations, decision records,
coverage excerpts, execution metadata, and original reports. Coverage excerpts remain
attributed, unverified literal text. Missing or ambiguous coverage stays UNKNOWN.
The last reviewer's attestation closes the comment, where `merge` reads it.
A commit GitHub does not have, such as one a rebase replaced, is named without a link or subject.
Each comment's key includes the full commit SHA, so republishing edits that commit's entry
without overwriting other commits' reviews or the legacy loop comment. All comments are
rendered and checked before any is posted; after a partial GitHub write failure, retry the
same content file to update posted entries and finish the rest.

The result's `comments` lists the published entries, and `summary` gives totals across the loop
and its outcome. Copy that summary into the PR description's review history details; native
usage records still belong in `usage.records`.

After every successful publication, `review publish` collapses older owned Shaka
review comments just published from the ledger, using their returned comment IDs.
Other reports, including legacy reports at the same revision, stay visible for explicit assessment.
Cleanup also skips when the current PR head has no report in that publication.
Its `cleanup` result lists confirmed edits, unavailable cleanup,
or a skip when no visible owned current-head report exists. A cleanup failure
returns nonzero while retaining the published comments; inspect the gap and retry.
For independent cleanup, use:

```sh
shaka review collapse OWNER/REPO NUMBER
```

The command links earlier Shaka local review comments from the publishing account
to its newest visible report for the current PR head. Findings and reports remain
expandable, and closing attestations stay readable by `merge`. Active reports for the same
commit stay visible; already archived reports link to the current one. Collapsing history does not resolve findings or native threads;
comments by other accounts stay intact. Before publication or standalone cleanup, carry still-applicable material findings
into the current review summary.

The standalone command also lists confirmed edits and unavailable cleanup. A failed
edit returns a nonzero exit; inspect the failure before retrying.
Without a visible owned current-head report, cleanup skips without failing. If the
PR returns to a previously archived head, republish its report before cleanup.
Both legacy and per-commit Shaka review keys are recognized. Cleanup works with
the per-commit publisher and can run independently after publishing.

After assessing completed CI feedback, also minimize obsolete bot review reports
and notices with GitHub's native **outdated** disclosure. Read them with `shaka comments`
at the current head first. Select reports that earlier commits have superseded and
notices that no longer help the reader. Minimize a CodeRabbit review-limit notice
when it contains no review findings; record `rate-limited; no review completed`
in the existing review summary even when the notice concerns the current head. Carry
still-applicable findings into the current summary; leave current review reports
and discussions with unaddressed material concerns visible. A different SHA alone
does not establish that findings are resolved. The agent makes this assessment;
Ruby does not parse each bot's report format or decide which comments are obsolete.

```sh
shaka review collapse OWNER/REPO NUMBER --head FULL_CURRENT_SHA \
  --bot-comment ISSUE_COMMENT_ID --bot-comment ANOTHER_ISSUE_COMMENT_ID
```

This selection mode minimizes only the specified bot issue comments admitted by
the trusted comment reader. It needs no local Shaka report or per-commit publisher.
Ruby checks bot identity, comment identity and content, an open PR at the expected
head, permission to minimize, and GitHub's stored minimization state. It preserves
the body and any existing minimization reason; human comments, native review
summaries and inline threads are outside this mode. The result lists confirmed
changes, already minimized comments and failures; failures return nonzero. A head
change after a confirmed mutation appears as both a confirmed change and a failure,
so the result retains the actual edit and reports the changed context. Head
and body checks cannot make GitHub's minimization mutation atomic with concurrent
changes. Inspect reported failures before retrying; no automatic rollback occurs.

Record available native
model, effort, and usage with `shaka usage --commit "$(git rev-parse HEAD)" --contribution review` on the
reviewer's source; missing evidence is UNKNOWN. Add `--format json` to each `shaka usage`
command in this guide and put its `record` in the description's `usage.records`. Do not publish raw sessions or private
context. A recovery
note's Chat link follows its [publication
rule](delivery.md#recover-an-unfinished-pr).

Automated review comments are advice, not merge permission. Required GitHub
approvals and checks remain gates. The merge helper checks native readiness and
the current commit; it does not read or judge review findings for the agent.
No extra approval, review receipt, or review service is introduced.

For example, a repo that already runs Claude on PRs can pin the report author in
its trusted `AGENTS.md` seam:

```markdown
Review: use our existing Claude Code Review GitHub workflow. Read its comments
and inline threads from the pinned `claude[bot]` report author, address demonstrated
defects, and recheck fixes before merge.
```

The [React on Rails review workflow](https://github.com/shakacode/react_on_rails/blob/e3d95bebc743ea9f9ab322f4b370667393c7627a/.github/workflows/claude-code-review.yml)
is an example: it posts comments and inspects Claude's execution result because
an unsuccessful review can otherwise report a successful action. Its separate
`@claude` workflow is a different capability, not required by this ordinary path.
