# What to expect from Shaka

<a id="pilot-status-and-limitations"></a>

Use Shaka with your repository's checks and review rules. This guide explains
setup choices, what happens when verification is incomplete, and how to resume
work or recover from access problems. For installation and everyday prompts,
see [Start here](getting-started.md) and [Working with Shaka](working-with-shaka.md).

## Choose how to start

Give Shaka a task. If setup is missing, it asks whether you want individual
or team settings. Individual setup avoids a team setup PR; shared
[repository setup](configure-repository.md) gives the team one configuration.
Setup alone does not authorize merging.

<a id="private-trials-available-tools-incomplete-guided-experience"></a>
<a id="individual-trials-available-tools-incomplete-guided-experience"></a>

### Individual setup

```text
$shaka <task or issue link>
Set up Shaka just for me. Go.
```

Individual settings remain outside commits in a repository without team setup.
[Merged #420](https://github.com/shakacode/shaka/pull/420) added delivery support for
individual reviewer choices, writing limits, opening instructions, and WIP preferences.
Custom code-review instructions and decision-checkpoint settings remain incomplete;
[#481](https://github.com/shakacode/shaka/issues/481) tracks those gaps.

The agent follows setup instructions to find existing commands and continue into
your task. That is not proof of seamless first-user delivery. The
[earlier acceptance report](https://github.com/shakacode/shaka/issues/277#issuecomment-5904859759)
records a maintainer-led feature PR with interventions on an earlier installation.
That evaluation predates #420; newer delivery support still needs a genuine new-user run.

[Merged #425](https://github.com/shakacode/shaka/pull/425) subsequently added independent
opening-check choices, including individual settings. [Merged #426](https://github.com/shakacode/shaka/pull/426)
added [settings previews](settings.md#preview-settings-before-adopting-them) for one task.
That settings preview differs from [trying another Shaka implementation](trying-pr-versions.md).

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
includes separate checkout-path and chat-locator fields, shown by default.
The current [WIP setting](settings.md#wipinclude_locations) hides both together;
[#482](https://github.com/shakacode/shaka/issues/482) tracks independent path visibility.
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

Use the [resume guide](working-with-shaka.md#resume-unfinished-work).
Recovery copies protect captured configuration, not feature changes or the agent
conversation. A [decision checkpoint](working-with-shaka.md#revise-earlier-guidance-and-try-again)
needs recorded guidance and recoverable work state. It is a separate agent procedure;
the Ruby `checkpoint` command does not capture or restore snapshots.
Tests in fresh processes do not establish genuine fresh-chat recovery.

## When the coding agent denies access

Expect the failed operation and path to be reported, with no claim of completion.
Use the host's supported permission mechanism for the necessary operation, then
retry and verify it. Shaka does not create a sandbox or grant filesystem access.

Host permissions can allow project edits while denying protected Git writes
needed by individual setup. The acceptance report records host-specific outcomes;
an unrestricted run does not prove that a sandboxed setup or retry will succeed.

<a id="what-the-pilot-has-established"></a>

## Recorded verification evidence

The [first-task acceptance report](https://github.com/shakacode/shaka/issues/277#issuecomment-5904859759)
records a verified consumer feature PR and separates passed, partial, and untested
cases for the evaluated installation. It includes supplemental recovery and
migration checks. Use the report to understand that evaluation's coverage;
newer versions need their own evidence for previously untested scenarios.
