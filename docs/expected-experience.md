# What to expect from Shaka

<a id="pilot-status-and-limitations"></a>

Use Shaka with your repository's checks and review rules. This guide explains
setup choices, what happens when verification is incomplete, and how to resume
work or recover from access problems. For installation and everyday prompts,
see [Start here](getting-started.md) and [Working with Shaka](working-with-shaka.md).

## Choose how to start

Use [shared repository setup](configure-repository.md) for team settings, or start
a task if the repository is already configured. The individual-trial option below
avoids a team setup PR but still has delivery limitations. Individual setup grants
neither team policy nor permission to merge.

<a id="private-trials-available-tools-incomplete-guided-experience"></a>

### Individual trials: available tools, incomplete guided experience

```text
$shaka Implement this small feature using this repository's existing commands.
Try Shaka just for me in this clone. Do not create a team setup PR or include
Shaka configuration in the feature diff. Keep merge policy ask.
```

This prompt describes the intended trial. It is not yet a demonstrated seamless
new-user path. The [first-task acceptance report](https://github.com/shakacode/shaka/issues/277#issuecomment-5904859759)
identifies the evaluated installation and records a verified maintainer-led
feature PR with interventions. Its entry workflow still selected team setup, and reviewer selection,
walkthrough, and handoff operations failed when reading an absent team seam.
An agent also edited individual settings to suppress local locations in public WIP Details.

The [individual setup procedure](https://github.com/shakacode/shaka/blob/main/skills/shaka/references/repository-setup.md#try-shaka-privately-in-one-clone)
exists, including recovery copies and exclusions. Its availability does not mean
every delivery operation supports that source. Expect an unsupported operation
to be reported with its failure and any manual fallback disclosed. A guided run
with interventions does not establish seamless new-user acceptance.
A newer installation needs its own validation before these limits are removed.

## Run an ordinary task

The [working guide](working-with-shaka.md#give-it-an-outcome) now covers task
prompts, model choices, and [what you get](working-with-shaka.md#what-you-get).
If a project has no usable checks, decide with the agent whether to add them or
report limited verification. Routine tasks should not require editing configuration
or PATH by hand.

## Understand the PR's settings and evidence

Expand the settings block to see the source and effective choices used for the
candidate. The publication helper redacts selected settings values; this is not a
general privacy scan. A settings block describes the run;
it does not prove tests or review happened.

| What changes or fails | Expected response |
| --- | --- |
| Validation fails | Fix the demonstrated problem, then rerun the affected checks. The PR stays unverified until they complete. |
| The candidate changes after tests or review | Check whether the evidence still covers the candidate; rerun affected work when it is stale. |
| Material command or review settings change | The workflow requires reassessing affected evidence. Live consumer settings transitions remain untested; do not assume an earlier pass is current. |
| A result is missing, a reviewer is unavailable, or CI is still running | Show the gap explicitly. Missing or stale evidence cannot satisfy a required gate. |
| An optional reviewer is pending | Disclose it and follow the configured waiting choice; required gates still apply. |

Public PRs must contain no private task content, operational settings, or
private-content fingerprints. Expandable details are still public. WIP Details
can include workspace and chat locations by default; decide whether to suppress
them before publication. See [WIP settings](settings.md#wipinclude_locations).
Privacy still requires the agent to inspect the publication.

## Decide whether to merge

See [merge choices](working-with-shaka.md#choose-a-merge-policy) for Ask, Auto,
and required approvals. The workflow instructs the agent to retain explicit task
merge authorization within its scope; that persistence remains untested in a live
consumer trial.

## Resume or change your checkout

| Scenario | Expected experience and recovery limit |
| --- | --- |
| Resume the same task with a PR | The workflow directs the agent to refresh PR state and evidence. Open WIP Details and return to the owner, or give a new chat the PR URL after the previous owner stops. Fresh-chat acceptance remains untested. |
| Resume before a PR exists | Supply the task and checkout. The intended path is local inspection; there is no PR record from which to recover missing choices. Fresh-chat acceptance remains untested. |
| Use a linked worktree with individual settings | Each worktree has its own local settings identity and recovery copy in the common Git directory. Host permissions must allow the required writes. |
| An outside pull adds team settings | Inspect adoption and compare saved individual settings. Default-branch team policy governs; do not overwrite it with the local copy. |
| Clean or delete a worktree with individual settings | Previously captured settings may be restored outside a checkout for comparison. Uncaptured edits and deletion of the common Git directory cannot be recovered from those copies. |
| Upgrade an older configuration layout | Use the reviewed migration procedure. Existing individual settings at the destination stop migration for comparison rather than being overwritten. |

Use the [resume guide](working-with-shaka.md#resume-unfinished-work) and
[migration guide](migration.md). Recovery copies protect captured configuration.
These copies exclude feature changes and the agent conversation.

## When the coding agent denies access

Expect the failed operation and path to be reported, with no claim of completion.
Use the host's supported permission mechanism for the necessary operation, then
retry and verify it. Shaka does not create a sandbox or grant filesystem access.

Codex workspace permissions can allow ordinary project edits while denying the
protected Git writes needed by individual setup. That denial was observed in normal
and linked worktrees; successful approval/retry remains untested. Claude Code
also needs permission for setup; supplemental checks completed with explicit Bash
allowances. An unrestricted session proves no sandbox outcome.

<a id="what-the-pilot-has-established"></a>

## Recorded verification evidence

The [first-task acceptance report](https://github.com/shakacode/shaka/issues/277#issuecomment-5904859759)
records a verified consumer feature PR and separates passed, partial, and untested
cases for the evaluated installation. It includes supplemental recovery and
migration checks. Use the report to understand that evaluation's coverage;
newer versions need their own evidence for previously untested scenarios.
