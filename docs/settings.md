# Settings reference

<a id="settings"></a>

Start with [Choose your settings](settings-guide.md) for common choices and
prompts you can give your agent. This reference covers each option and its limits.

Settings live in `.agents/shaka/config.yml`. Ask your agent to
[configure the repository](configure-repository.md), or edit the file in a PR.

Browse [this repository’s configuration](https://github.com/shakacode/shaka/blob/main/.agents/shaka/config.yml) for a
commented example with explicit defaults and repository-specific review choices.
Optional choices without fixed defaults, such as the base branch and local reviewer models, stay commented.

## Which settings apply?

Shaka uses one configuration source for the task. It does not combine individual
settings with shared team settings.

| Repository setup | Settings used |
| --- | --- |
| A settings PR is explicitly selected for this task | The complete configuration at its selected commit. |
| Shared Shaka settings exist on the default branch | The default-branch configuration, including when reviewing a PR that changes it. |
| No shared settings; individual setup is configured | Your local `.agents/shaka/config.yml`, kept out of Git. |

Omitted optional values use Shaka's defaults. An explicit task choice takes
precedence where an option supports it, such as choosing Ask for one task.
Each option below describes any such override. Individual settings govern
delivery preferences, such as AI reviewers and writing limits; they cannot
disable required merge gates or authorize merging.

A settings PR becomes the team's default after it merges into the default branch.
You can also select it for one task before adoption. Local settings do not override
shared settings. Individual custom code-review instructions and
checkpoint settings still use the shared source or defaults;
[#481](https://github.com/shakacode/shaka/issues/481) tracks complete individual support.

[Merged #420](https://github.com/shakacode/shaka/pull/420) brought individual delivery
preferences to reviewers, writing limits, opening checks, and WIP reporting.
[Merged #425](https://github.com/shakacode/shaka/pull/425) subsequently added independent
opening-check choices. [Merged #426](https://github.com/shakacode/shaka/pull/426) added
settings previews for one task.

## Preview settings before adopting them

Keep proposed settings in an open PR and try them before making them your team's
defaults. Teammates can select the same PR for their tasks:

```text
$shaka <task or issue link>
Use settings from PR #123.
```

To switch an existing task:

```text
$shaka Switch this task to settings from PR #123.
```

The selected PR supplies the complete configuration, including reviewer choices
and merge preferences. Individual settings do not overlay it. An explicit task
choice, such as Ask, still takes precedence where supported. GitHub's required
checks and approvals still apply.

The agent records the selected PR and pinned commit on the task's PR. The selection
survives a fresh chat and stays with that task's branch and worktree. Updates require
explicit selection of a newer commit, followed by fresh affected checks and reviews.
Ask the agent to stop the preview to return to ordinary settings.

A local branch can prepare an experiment; the PR makes its choices visible before
team adoption. Ask to keep that settings PR open if you want to continue experimenting.

## `merge.preference`

**Required.** Values: `ask` or `auto`. Setup defaults to `ask`.

```yaml
merge:
  preference: ask
```

With `ask`, merge the ready PR on GitHub or tell the agent to merge the reviewed
commit. With `auto`, the agent merges after required checks, reviews, and approvals,
subject to the repository's restrictions. Some changes still need your decision.
Shaka uses your account's existing GitHub
permissions; an account that can bypass protection needs no extra Shaka setting.

Set a task's preference with `Use merge policy auto`. This is a task instruction;
editing the PR's settings does not change its own merge authority. Required human
approvals still apply. `Go` starts work; it is not merge consent. Ruby checks
readiness; the agent establishes your task-scoped authority. See
[merge policy](working-with-shaka.md#choose-a-merge-policy).

## `merge.required_checks`

**Optional.** CI checks that must pass before Shaka treats a PR as ready. Use it
when GitHub cannot require checks, such as on a private repository on the GitHub
Free plan.

```yaml
merge:
  preference: ask
  required_checks:
    - test
```

GitHub's required checks come first. If the base branch requires any, Shaka uses
those and ignores this list.

Otherwise, each listed check must appear on the PR and pass. Neutral and skipped
results count as passing, as they do on GitHub. If a listed check never appears,
the PR is blocked, so a renamed job cannot quietly drop out of the gate. Use the
names `gh pr checks` shows: CircleCI, for example, reports one check per workflow,
not per job.

The list governs only what Shaka does. In Ask mode, the agent waits for these checks
before it reports a PR ready and labels it `awaiting-merge-approval`. In Auto mode,
`shaka merge` refuses to merge until they pass. GitHub does not know about the list, so it
does not stop anyone from clicking merge. Nothing ties a name to a specific
workflow either, so a PR could add a job with a listed name. For protection that
GitHub enforces, use a ruleset or branch protection.

## `merge.limits`

**Optional.** Size limits for a merge the agent submits. A PR at a limit still
merges; one past it goes back to you.

```yaml
merge:
  preference: auto
  limits:
    max_changed_files: 29
    max_changed_lines: 999
    max_commits: 9
```

The values above are the defaults. Set any key to a positive integer to change
it; omitted keys keep their default. Changed lines are additions plus deletions.

When a PR is past a limit, or GitHub does not report its size, `merge` refuses
it. The agent then reports the counts and hands the PR back as Ask. To let the
agent merge it, confirm that commit in chat or
[approve it](working-with-shaka.md#find-prs-waiting-on-you). The confirmation
still counts after a clean rebase, or after conflict fixes that change no
behavior; any other new commit needs another confirmation. Required checks,
reviews, and approvals still apply.

`merge` checks the counts and that a confirmation names the commit being
merged. Whether you actually confirmed it is the agent's responsibility; the
[enforcement reference](workflow.md#what-is-enforced) explains the boundary.
Put other project restrictions in `AGENTS.md`.

## `review.required`

**Required.** Values: `meaningful_changes`, `always`, or `none`.

This controls when configured CI review reports are required. Options:

- `meaningful_changes`: implementation changes; trivial prose can skip with a reason.
- `always`: every PR, including trivial changes.
- `none`: no configured CI review backstop, and `shaka merge` does not check for a
  local review. Omit `ci_review_jobs` with this setting.

Meaningful implementation also gets a local adversarial review before push:

- Use a separate session without the implementation conversation.
- Prefer a different provider and model. If other reviewers are unavailable, the
  current workflow allows the implementation model in a fresh session.
- Address findings before pushing.
- To have several reviewers read each commit, set
  [`review.local_review_count`](#reviewlocal_review_count).

![A local review runs before push, configured CI review jobs report after push, and the merge check requires a posted review covering the merged commit before the agent merges.](img/review-layers.svg)

`shaka review run` verifies the reviewer process completed and returned a report
for the expected commit. `shaka review check` validates a supplied report but does
not prove a reviewer process ran.

Before it merges, `shaka merge` checks that the PR has a local review of the
commit being merged. The agent posts the review report as a PR comment, and the
report's last line names the commit and the reviewer:

```text
REVIEWED <commit> BY <provider>/<family> EFFORT <effort> FINDINGS <count>
```

`merge` counts only comments from the GitHub account running the merge, and only
when that line ends the comment. Any reviewer counts, including the
implementation model in a fresh session.

A review of an earlier commit still counts in two cases:

- **Updated from the base branch.** Bringing the branch up to date with the base,
  by merge or rebase, keeps the review when there were no conflicts and nothing
  else changed. `merge` checks this with Git in the local checkout: the head must
  match, file for file, what merging the reviewed commit with the new base
  produces. The check runs Git's built-in merge in a temporary repository, so no
  merge driver or script runs and nothing is written to your repository. If Git
  is older than 2.41 or those commits are not in the checkout, `merge` asks for a
  new review or a waiver instead.
- **Ordinary Markdown since.** Every later change is ordinary Markdown. Agent
  instructions are not ordinary Markdown: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`,
  `SKILL.md`, and files under `.agents/`, `.claude/`, `.cursor/`, `.github/`, or
  `skills/` need a new review.

When no review applies, `merge` stops before merging. A maintainer can record a
waiver reason when review was skipped on purpose, a later commit only fixed nits,
or a CI review covered the commit. The waiver also covers a PR whose
comments GitHub cannot list. With `review.required: none`, `merge` skips this check.

The merge result shows the review it relied on, or the waiver reason, under
`review_evidence`. That records what the posted line says. It does not prove a
reviewer process ran or that its findings were fixed.

## `review.ci_review_jobs`

**Required unless `review.required` is `none`.** List the GitHub job names that
produce review reports, such as:

```yaml
review:
  required: meaningful_changes
  ci_review_jobs:
    - claude-review
  ci_review_wait: one
```

The agent reads reports according to `ci_review_wait`; a green job alone does not
prove review completed. GitHub's required merge checks are configured separately.

## `review.ci_review_wait`

**Optional. Default: `one`.** Values: `none`, `one`, or `all`.

| Value | Wait before merging |
| --- | --- |
| `none` | No CI review report; local review still applies |
| `one` | At least one configured reviewer reports on the current commit |
| `all` | Every configured reviewer reports on the current commit |

Local review does not waive `one` or `all`. With `review.required: none`, no
configured review jobs apply. GitHub's required checks and approvals apply in
every mode. A task can increase the wait, but cannot lower the repository minimum.

The agent counts verified reports. The merge helper permits optional pending
checks (`UNSTABLE`) for `none` and `one`; `all` requires `CLEAN`.

## `review.local_max_rounds`

**Optional. Default: `5`.** A positive integer, validated by `shaka seam check`.

This bounds the commits reviewed in one local review ledger. For example, `3` lets
an initial review and two follow-up reviews run before the helper refuses another.
With [`local_review_count`](#reviewlocal_review_count) above 1, all the reviewers of one
commit together use one of these turns, so `3` with two reviewers allows six reviews
across three commits.
The runner reads the setting from the supplied trusted `--settings-ref` (or
`--criteria-ref`). Without a reference, it uses the default of five.

If the cap leaves an unfixed defect, the agent stops before pushing and tells you.
You can reassess the task, split it, or choose to push anyway. An authorized push
publishes a visible **Loop bound reached** section listing unresolved defects,
the rounds in which they appeared, and any that returned after a recorded fix.
It includes a prompt to reassess contradictory requirements, excessive scope,
or impossible constraints. Ruby bounds review rounds; the agent handles your push decision.

If the cap prevents review of a last-round fix, the agent also stops before pushing
and tells you. Publication still refuses that unreviewed fix; reassess the task
before continuing.

## `review.local_review_agents`

**Optional.** Choose which reviewers Shaka tries first. Put a reviewer from a
different provider first to get another perspective on the change. Each reviewer
needs its CLI installed and signed in, or its API credentials on the machine doing the review.

Ask your agent:

> $shaka Prefer Claude for code review.

```yaml
review:
  local_review_agents:
    - provider: anthropic
      model_family: claude
      model: claude-opus-5-5
      effort: medium
    - provider: openai
      model_family: codex
      model: gpt-6-sol
      effort: medium
    - provider: xai
      model_family: grok
      model: grok-4.7
      effort: medium
```

Shaka prefers a different provider from the one that implemented the change,
then follows your list order among available reviewers. These settings choose
the available choices; [`local_review_count`](#reviewlocal_review_count) chooses how
many run. Listing three does not require all three to review every change.

### Model and effort values

Use these provider and family pairs for Shaka's supported local reviewers:

| Reviewer | `provider` | `model_family` | Effort values Shaka recognizes |
| --- | --- | --- | --- |
| Claude Code | `anthropic` | `claude` | `low`, `medium`, `high`, `xhigh`, `max` |
| Codex | `openai` | `codex` | `low`, `medium`, `high`, `xhigh` |
| Grok | `xai` | `grok` | `low`, `medium`, `high` |
| DeepSeek via OpenRouter API | `deepseek` | `openrouter` | `low`, `high`, `max` |

DeepSeek is an optional reviewer alongside your existing reviewers. Add this entry to your trusted
reviewer list when you want Shaka to send the prompt and diff to OpenRouter and
its selected upstream provider. Start with low effort; high-effort trials on a
large diff sometimes consumed the completion budget without returning a report.

```yaml
- provider: deepseek
  model_family: openrouter
  model: deepseek/deepseek-v4.1-flash
  effort: low
```

Set `OPENROUTER_API_KEY` in the review process environment; keep it out of repository
files. No separate reviewer CLI is needed. The adapter supports only this explicit
[OpenRouter model](https://openrouter.ai/deepseek/deepseek-v4.1-flash); it refuses other
models and unsupported effort values before sending a request. Omitted effort uses
the provider default and remains UNKNOWN in Shaka's attestation.

Account settings govern provider routing and data policies. Shaka does not enforce
a provider allowlist or zero data retention. Before using private code, confirm
that your account's provider and privacy policies permit every possible recipient.
Keep your existing review checks while evaluating this optional reviewer; quality,
completion and savings remain unproved across workloads.

This reviewer receives the supplied diff and trusted criteria, with no tools or
filesystem access. It cannot inspect unchanged callers or execute tests. Reports
retain that coverage limit. Requests use the review timeout, make no automatic
retry or model substitution, and reject malformed, truncated or unattested output.
Existing reviewers and merge preferences remain unchanged.

OpenRouter's response records token counts and account cost; missing usage stays
UNKNOWN. See [usage and cost](reference/usage-and-cost.md) for how to interpret
the PR's reported cost and coverage.

Choose a `model` available to that reviewer. The CLI example names above are
examples, not a closed list: newer names can run with a warning. Model names
cannot contain spaces. Effort names use lowercase.

Claude accepts only its listed effort values in Shaka. Codex and Grok values
outside the table produce a warning and still reach the CLI, which decides
whether they are supported.

Set `model` and `effort` to control review cost. Omit either to use the reviewer's
default for that setting; Grok requires a model from the configuration or the
task. A task can request a different model or effort for one review. Without a
reviewer list, Shaka uses a fresh review context with the model that implemented
the change.

### Use these settings from Cursor

The same repository settings apply when you work in
[Cursor](coding-agents.md). In a Cursor Agent chat, ask:

> /shaka Configure local reviews to prefer Grok 4.7 at medium effort, with
> Claude at medium effort as the next choice.

Cursor is the coding host. Reviewer entries identify the model provider and
reviewer CLI, so use `xai` / `grok` for Grok, including when your implementation
was written in Cursor. Shaka's local review runner supports the three CLIs and the
OpenRouter API adapter in the table. Cursor supplies the coding host rather than a reviewer CLI.

### Understand a reviewer warning

For these reviewers, Shaka flags unfamiliar model and effort names and likely
typos. You'll see the warning in the repository health check and
a **Reviewer settings** notice on the published local review. Check the spelling
and confirm that the model and effort are available to your reviewer. Shaka
keeps your chosen model; it does not substitute another one.

Most warnings allow the review to run. An unsupported Claude effort stops it;
choose one of Claude’s listed effort values to continue.

Put project-specific review criteria in `AGENTS.md`. To check reviewer settings,
use the [availability prompt](getting-started.md#2-choose-individual-trial-or-team-setup).
To choose how many hosted review reports to wait for, use
[`review.ci_review_wait`](#reviewci_review_wait).

### Add a second reviewer

A review from the provider that wrote the change shares its blind spots. When the
published review shows a **Reviewer fallback** notice, no listed reviewer from another
provider could run on that machine. Install one of the listed CLIs and sign in once
with the account that should pay for reviews:

- Codex: follow the [official CLI installation](https://github.com/openai/codex),
  then run `codex login`.
- Claude Code: follow the [official setup](https://code.claude.com/docs/en/setup),
  then run `claude` and sign in. Keep the
  normal sign-in; Shaka does not use `--bare`, which ignores it.
- Grok: follow the [Grok Build setup](https://docs.x.ai/build/overview), then run
  `grok` and sign in. Shaka looks for `grok`; another program named `agent` is
  not evidence of an installed Grok reviewer.

Then list that provider in `local_review_agents`. The next review picks it, and the
published review names it in its summary table instead of the fallback notice.

## `review.local_review_count`

**Optional. Default: 1.** How many reviewers from `local_review_agents` read each
commit before its findings are fixed. With more than one reviewer, the agent starts
those reviews concurrently.
The helper refuses to record findings while a started review is still running.
The agent combines their findings so a problem two reviewers found is fixed once.

Claude implements, and Codex and a fresh Claude session both review:

```yaml
review:
  required: meaningful_changes
  ci_review_jobs: [claude-review]
  local_review_count: 2
  local_review_agents:
    - provider: anthropic
      model_family: claude
    - provider: openai
      model_family: codex
```

The first reviewer comes from a provider that did not write the change whenever one
can run, here Codex. The others follow the list order, so the second is Claude in a
fresh session, without the implementation conversation. If Codex had written the
change, the order would be Claude, then Codex. When the agent finds a reviewer's CLI
missing or signed out, fewer reviewers read that commit, and from the next commit the next
listed reviewer takes its place.

Each extra reviewer adds cost and may increase elapsed time. The PR's
review comment shows every reviewer's rounds, and one review of the final commit is
enough for `shaka merge`. A task can ask for a different number, which wins for that
task.

## `review.prompt_file`

**Optional. Default: Shaka's [review instructions](../skills/shaka/config/review-prompt.md).**
A Markdown file in your repository that replaces what the local reviewer looks for
and how it reports. Copy the default to start.

```yaml
review:
  required: meaningful_changes
  ci_review_jobs: [claude-review]
  prompt_file: .agents/review-prompt.md
  local_review_agents:
    - provider: openai
      model_family: codex
      prompt_file: .agents/review-prompt-codex.md
    - provider: anthropic
      model_family: claude
```

To give one review agent different instructions, set `prompt_file` on that
agent's entry in `local_review_agents`. It replaces `review.prompt_file` when that
agent reviews. Here Codex reviews with `.agents/review-prompt-codex.md`, and Claude,
which has no `prompt_file` on its entry, uses `.agents/review-prompt.md`.

Outside a settings preview, Shaka reads the file from a trusted default-branch revision, so a PR that
changes it is reviewed with the current version. Without a trusted prompt,
including during individual setup without team settings, the reviewer uses
Shaka's default instructions. Individual custom prompts are not applied;
[#481](https://github.com/shakacode/shaka/issues/481) tracks that gap.
[Settings previews](#preview-settings-before-adopting-them) use prompt files
from the selected commit before team adoption.

Settings validation fails when a configured file is missing, empty, larger than
100 KB, or not UTF-8. Replacement prompts keep the rules that identify the reviewed
commit and prevent edits. See [what Shaka enforces](workflow.md#what-is-enforced).

The file configures local reviews. A CI review job gets its prompt from its own
workflow; to give it the same instructions, have the workflow read this file.

## `review.post_implementation`

**Optional.** Choose who evaluates the result at the **checkpoint**:
whether it solves the intended problem, earns its maintenance cost, and what to do
next. This differs from the code walkthrough explaining the implementation.
With no settings, Shaka invokes Codex (`gpt-6.1-sol`) at medium effort using its
[default product prompt](../skills/shaka/config/post-implementation-prompt.md).

For example, to ask Claude Sonnet to reconsider each finished change with your
project's audience in mind:

```yaml
review:
  required: meaningful_changes
  ci_review_jobs: [claude-review]
  post_implementation:
    reviewer: anthropic/claude
    model: sonnet
    effort: high
    prompt_file: .agents/shaka/product-checkpoint.md
```

The prompt file and repository choices come from the trusted default branch,
or the selected settings PR's pinned commit during a preview.
A task's explicit choices take precedence. See
[the checkpoint](pr-verification.md#checkpoint)
for what the checkpoint means for your merge decision.

The PR records the conclusion, reasons, execution settings, and available native
usage. A failed invocation stays incomplete. “Simplify/reframe”, “Do not merge”, or
unresolved substantive concerns block readiness and Auto; green technical checks
and changed settings do not clear them. Earlier executions stay visible on the PR.
Setting `enabled: false` in the selected configuration opts out and
requires a visible note. Individual checkpoint choices, including opt-out and
custom instructions, currently do not apply; [#481](https://github.com/shakacode/shaka/issues/481)
tracks this gap. [Settings previews](#preview-settings-before-adopting-them) apply
these choices from a selected settings PR.

See [checkpoint terms and current report labels](pr-verification.md#checkpoint).
The current automated gate concerns pre-merge readiness; these terms do not add
an approval step or a general outer-loop mechanism.

Ruby validates settings, execution outcome, report shape, and head binding.
The AI reviewer assesses whether the change solves the problem and is worth
maintaining. The task owner supplies the original problem and evidence, resolves
concerns, and establishes merge readiness. Final merge preparation
requires a report for the current commit with no unresolved concerns, or an explicit
opt-out.

<a id="opening_check"></a>

## `pr_description.opening_check`

**Optional.** Check whether the first sentence leads with a useful outcome for
its reader. This is writing advice, not a check of the whole description's accuracy.
A failed check does not block publication or merging.

> $shaka Use Codex for opening checks.

```yaml
pr_description:
  opening_check:
    enabled: true
    reviewer: openai/codex
    model: gpt-6.1-sol
    effort: medium
    # prompt_file: .agents/shaka/opening.md
```

Choose the provider and model that works best for your writing. It can be the
same provider you use to develop the change. The opening check runs in a separate
session and does not inherit the implementation conversation.

You can omit the whole section to use the defaults below. The opening check
shares the code-review preference order when it chooses a reviewer, but uses
its own model and effort choices. It does not copy those from code review.

| Setting | Effect when omitted |
| --- | --- |
| `enabled` | `true`. Set `false` to turn the opening check off. |
| `reviewer` | The agent chooses from your local AI code reviewers. An explicit `provider/family`, such as `openai/codex`, selects the opening reviewer independently. |
| `model` | The selected CLI's default model for Codex or Claude. Grok requires a model; OpenRouter requires `deepseek/deepseek-v4.1-flash`. To name a model, also set `reviewer`. |
| `effort` | `low`. Use a thinking level supported by the selected provider. |
| `prompt_file` | Shaka's default opening instructions. |

For example, `reviewer: openai/codex` with no `model` uses the Codex CLI's
built-in default model. Shaka runs Codex with personal configuration disabled.
Adding `model: gpt-6.1-sol` pins the opening check to that model. Omit the model
to follow CLI defaults, or pin it for predictable results and cost. Shaka does
not currently load shared settings from another GitHub repository.

For `reviewer: deepseek/openrouter`, use `model: deepseek/deepseek-v4.1-flash`
and `effort: low`, `high`, or `max`. Shaka checks these fixed adapter choices
when it loads the settings. Grok also needs an explicit model because its CLI
has no default.

The top-level `opening_check` section remains supported for existing setups.
Use one location for these settings; Shaka rejects a configuration that supplies
both. New setups use `pr_description.opening_check`.

The older `external_enabled` setting remains supported: `false` keeps the check
in the coding chat instead of launching a separate reviewer. Use either that
legacy setting or `enabled`, not both. With `enabled: false`, Shaka returns no
parsing prompt and launches no opening reviewer; the agent still follows your
ordinary writing instructions.

[Merged #425](https://github.com/shakacode/shaka/pull/425) added these independent
choices and the fully disabled state after #420. At #420's merged revision,
opening checks used the code-reviewer list at low effort, without independent
configuration for their provider, model, or effort. The legacy
`external_enabled: false` still means a check in the current chat.

### Customize the opening check

Copy [Shaka's default opening prompt](https://github.com/shakacode/shaka/blob/main/skills/shaka/config/opening-prompt.md)
and set `prompt_file` to your copy. The path is relative to the repository root,
not the configuration file's directory. For example,
`prompt_file: .agents/shaka/opening.md` selects that file beneath the repository
root. Both the separate AI session and the coding agent use those instructions.
Leave the setting out to use Shaka's default.

The [configuration source](#which-settings-apply) determines which `prompt_file`
setting applies. A settings preview reads the prompt at its selected commit.
Without a preview, Shaka reads the file as follows:

- **Shared team settings:** commit the prompt with the settings PR. Shaka uses
  the version on the default branch, so a PR cannot rewrite its own review rules.
- **Individual setup:** put the prompt in `.agents/shaka/`, alongside your local
  settings. For example, `.agents/shaka/opening.md` stays out of commits and applies to
  your task. A symlink cannot point outside that directory.
- **A prompt elsewhere in the repository:** Shaka reads the default-branch
  version, even during individual setup. A file that exists only on your feature
  branch cannot supply instructions.

Prompt files must pass the [review prompt file checks](#reviewprompt_file).
Custom instructions cannot change the JSON fields Shaka expects in the response.
Shaka treats the PR opening as text to assess, not as instructions to follow.

If the selected reviewer cannot run, Shaka returns the reason and the prompt for
the coding agent to apply. It preserves your model choice. A successful result
is reused while the opening, instructions, provider, model, and effort stay the
same.

## `prose_limits`

**Optional.** Limit the length of PR descriptions and code walkthroughs. These
limits are checked in code before publication. Recommendations and review
replies follow the agent's writing instructions but are not checked against
these limits.

```yaml
prose_limits:
  max_sentence_words: 35
  max_paragraph_words: 100
  max_description_words: 300
  words_per_changed_line: 4
```

The values above are the defaults. Set any key to a positive integer to change
it; omitted keys keep their default. Each limit counts selected prose.
Code blocks, tables, headings, quotes, link addresses, and the body of a
collapsed details block do not count. A collapsed block's summary label counts,
and an inline code span counts as one word.
In a description, only the part Shaka manages counts; text that people or other tools
add outside it is left alone.

- No sentence may run past `max_sentence_words`.
- No paragraph or list item may run past `max_paragraph_words`.
- The whole text may use 150 words plus `words_per_changed_line` for each
  changed line. A 6-line fix allows 174 words; a 100-line change allows 550.
- The description also stops at `max_description_words`, however large the change.

When text breaks a limit, nothing reaches GitHub. The command exits with an
error identifying the long passage or total word count. The agent shortens the
explanation before publishing.

For example, a 19-line change with a 950-word walkthrough is refused. The agent
splits long paragraphs, moves supporting detail into collapsed details, and
links to the code, then publishes again.

### Which limits apply?

The [configuration source](#which-settings-apply) determines the limits. For
example, with individual setup, a local 20-word sentence limit applies to
both your PR description and walkthrough. A shared team's changed limit takes
effect after its settings PR merges.

When the agent publishes without a settings reference, Shaka uses its defaults.
If it cannot read the referenced settings, the description can use the defaults
and reports why. The walkthrough stops until the settings can be read.

## Standard command scripts

Connect your existing tools at these fixed paths:

| Script | Required? | Purpose |
| --- | --- | --- |
| `.agents/shaka/bin/setup` | Yes | Install dependencies |
| `.agents/shaka/bin/test` | Yes | Run tests; accept focused arguments |
| `.agents/shaka/bin/validate` | Yes | Complete checks before publishing |
| `.agents/shaka/bin/validate-local` | No | Faster checks before local review |
| `.agents/shaka/bin/trigger-hosted-ci` | No | Start deferred CI after local fixes; requires `validate-local` |

A wrapper can call an existing command. `seam init` generates each required wrapper;
it finds the repository root with Git, so it works from any directory and in linked
worktrees. To run a different command, change only its last line, for example:

```sh
exec bundle exec rake test "$@"
```

`exec` preserves the command's exit status and signals. A symlink to a tracked
executable also works if its directory, environment, and arguments already match.

Scripts must be executable and resolve within the repository. `.agents` and the
directories holding the configuration and scripts must be real directories.
Removing an optional check already on the default branch requires an explicit,
maintainer-approved policy change.

## `base_branch`

**Optional. Default: the repository's default branch.**

Use `base_branch: develop` to start from and target `develop`. An explicit task
choice or existing PR target takes precedence. A base outside the configured or
default branch needs confirmation and uses Ask. Policy always comes from the
default branch.

## `branches.name`

**Optional. Default: `'{login}-{host}/{issue}-{description}'`.**

```yaml
branches:
  name: '{login}-{host}/{issue}-{description}'
```

| Placeholder | Meaning |
| --- | --- |
| `{login}` | Authenticated GitHub login |
| `{host}` | Coding-agent slug, such as `codex` or `claude` |
| `{issue}` | Issue, PR, or work-item number; required in the template |
| `{description}` | Short task description |

For example: `alex-codex/42-fix-search`.

When a task comes from a tracker that offers a branch name, such as Linear's
**Copy git branch name**, the agent uses that name instead of the template.
Trackers link a pull request to its
work item through that branch name. Git must accept the name as a branch name.

## `pr_description.show_shaka_credit`

**Optional. Default: `true`.**

PR descriptions show *PR prepared with [Shaka](https://shaka.shakacode.com/).* below
the opening summary. The credit helps readers discover the workflow that prepared
the PR and try it on their own project.

When Shaka is configured for a repository, the credit helps teammates discover its
workflow. For private repositories, leave attribution enabled while introducing
Shaka, then turn it off once the team is familiar with it.

To hide the credit, set:

```yaml
pr_description:
  show_shaka_credit: false
```

The setting applies to PR descriptions. Walkthroughs and replies do not carry this
credit. Hiding it keeps verification, execution provenance, and usage visible in
their existing sections. Shaka also omits the credit when repository settings
cannot be read.

## `pr_description.show_human_comments`

**Optional. Default: `true`.**

PR descriptions list the comments people wrote under **Human comments**, so they are
not lost among agent posts. [See what people said](pr-verification.md#see-what-people-said)
shows the list and explains each column.

To leave the list out of this repository's PR descriptions, set:

```yaml
pr_description:
  show_human_comments: false
```

A description published after that change drops a list an earlier one showed.
Shaka keeps the list when repository settings cannot be read, because leaving it
out would hide what people wrote.

## `pr_description.max_human_comments`

**Optional. Default: `20`.**

The list shows at most this many rows, open comments first, and says how many more
it left out. Use a positive whole number:

```yaml
pr_description:
  max_human_comments: 40
```

How much of a comment the list repeats is not a setting. The list quotes a comment
only when it has at most 12 words and 90 characters. A longer one is already on
the PR, so the list shows the agent's one-line summary and links to it.

## `wip.include_locations`

**Optional. Default: `true`.**

```yaml
wip:
  include_locations: true
```

Include two separate fields in **WIP Details**: the **checkout path**, which can
reveal local directory names, and the **chat locator**, which helps resume the
owning chat when reachable. Both team and individual setup write `true`.
The description renderer replaces both
location fields with `REDACTED` when the selected setting is explicitly false.
When settings were not read or could not load, it withholds locations and explains
how to reload the policy. Ownership, state, next action, and the current commit
remain visible. When locations are allowed but the host lacks one, its value is
`UNKNOWN`.

A Codex locator such as `codex://threads/...` points to a local conversation; it
does not create a publicly shared snapshot. Other hosts' links can have different
access rules. The agent inspects both fields before publication.

[#482](https://github.com/shakacode/shaka/issues/482) tracks retaining chat locators
while making checkout-path visibility independently configurable, including in
individual settings. Neither #425 nor #426 splits these fields.
Hiding them does not remove private information elsewhere in a PR.
Expandable sections on public PRs are public too.

## `repo_prefix`

**Optional. Default: a label derived from the repository name.**

Use 1–6 uppercase ASCII letters or digits, such as `repo_prefix: SHOP`, to label
chat titles: `SHOP PR #42 · Fix checkout`. The
[repository catalog](repository-catalog.md) reports duplicate prefixes.

## `version`

**Required. Currently `1`.** This identifies the configuration format, not the
installed Shaka release.

Unknown keys and invalid values produce an error. Link requirements and design
plans from `AGENTS.md`.
