# Working with Shaka

## What you get

The agent reproduces bugs, tests new behavior, runs your checks, and handles
independent review findings before pushing.

The PR description explains the outcome and decisions that need your attention.
A code walkthrough explains implementation choices and alternatives, with links
to the reviewed code. Tests, review findings, and screenshots help you evaluate
the result. Expandable sections hold usage estimates, detailed checks, and
**WIP Details** for unfinished work.

Use that record to decide whether to merge, then return to it when evaluating
the approach or how the work was checked. See
[what a Shaka PR gives you](pr-verification.md#read-a-pr-for-your-decision).

The agent handles routine choices and asks about decisions affecting the product,
scope, or risk.

Your agent's permissions, project commands, and GitHub rules determine what it
can complete. Missing tests, unavailable reviewers, and access failures should
appear as concrete gaps, never as a claim of success. See
[what to expect from Shaka](expected-experience.md).

## Give it an outcome

Describe the result or provide an issue or task link. Include constraints the
agent could not infer:

```text
$shaka Add CSV export to the orders page. Reuse the filters shown on screen.
Keep merge policy ask. Go.
```

Examples use Codex's `$shaka`. Use `/shaka` in Claude Code, Cursor, or OpenCode;
in Pi, load the installed skill. [Install and configure Shaka](getting-started.md)
if this is your first task.

Shaka checks for existing work and recommends a model and effort level. `Go`
without naming either starts with your agent's current settings, even if they
differ from that recommendation or cannot be reported.

## Choose the outcome you need

Use the same installed skill for a plan, an existing PR review, recovery, or
repository setup. State the stopping point in your prompt.

### Get a plan before implementing

```text
$shaka Plan CSV export for the orders page. Compare a simple download with
a background export. Planning only; do not implement or open a PR yet.
```

The agent returns a compact execution prompt with the proposed scope, tradeoffs,
recommended model and effort, and available usage. It stops before implementation
edits. Use the returned prompt when you decide to start delivery.

### Keep a plan across chats

When a task needs several PRs or a detailed plan, Shaka saves the steps and
important decisions in the original issue or tracker item. It updates the plan
as the work changes. If it needs permission to write there, Shaka asks.

For larger design decisions, Shaka may suggest a separate document linked from
the task.

To pick up the work in a new chat, give Shaka the same task link after the previous
agent has stopped. Shaka reads the plan and checks the PRs before continuing.

### Review an existing PR

```text
$shaka Review https://github.com/OWNER/REPO/pull/N for correctness and missing
tests. Review only; report findings without editing, publishing, or merging.
```

Replace the URL with your PR. The agent reviews its current revision and reports
findings and verification gaps, then stops. This request does not take over delivery
or fix findings; ask separately when you want those changes.

### Resume a PR you already started

```text
$shaka Resume https://github.com/OWNER/REPO/pull/N. The previous owner has
stopped and handed this work to me. Keep merge policy ask. Go.
```

Confirm that handoff before using this prompt. The agent reads **WIP Details**,
checks live ownership and the PR's current revision, and continues the unfinished
work. Under Ask, it returns a verified PR for your merge decision, or explains
the remaining blocker. See [resume unfinished work](#resume-unfinished-work)
for recovery after a crash or when no PR exists.

### Configure a repository for your team

```text
$shaka Configure this repository for Shaka. Reuse its existing setup,
test, and validation commands. Explain the review and merge choices.
Use merge policy ask.
```

For a repository without Shaka settings, the agent prepares a separate setup PR
and names the reviewed commit for you to merge on GitHub. It stops there; proposed
settings cannot govern feature work until that PR merges. See
[repository setup](configure-repository.md#set-up) for the choices, or
[individual trials](expected-experience.md#individual-trials-available-tools-incomplete-guided-experience)
to try Shaka locally without team adoption.

These are requests to the existing workflow. Separate stage skills such as
`shaka-plan` and `shaka-review` are not included in the current installation.

## Choose a merge policy

| Policy | What happens |
| --- | --- |
| **Ask** (default) | Review the ready PR, then merge it on GitHub or approve it so the agent merges. |
| **Auto** | The agent merges after required checks, review, and approvals. |

![A ready PR follows Ask, where you merge or approve it, or Auto, where the agent merges. A PR that is too large or risky returns to you under Auto.](img/merge-policy.svg)

Set the choice in your prompt: `Use merge policy ask` or `Use merge policy auto`.
Repository restrictions and required approvals still apply. Trust, authentication,
release, and other consequential changes need explicit human review. A PR past the
[size limits](settings.md#mergelimits) goes back to you before the agent merges it.
Merging a feature PR does not by itself publish a package or deploy a release.

## Useful tips

- **Start small.** Pick a fix whose result you can recognize. Say what should happen
  and what should stay the same; let Shaka manage the checks and review.
- **Choose settings when you need to.** Activate a model in your coding agent, then
  name it in your prompt, for example `Use Sol, medium effort. Go.` A prompt cannot
  switch the model. Naming either setting can trigger a pause if it is unavailable,
  unverified, or differs from Shaka's recommendation.
- **Keep public PRs public-safe.** Tell the agent before publication if local paths
  or chat links should be hidden. [WIP settings](settings.md#wipinclude_locations)
  control those fields; the agent still needs to inspect all published content.

## Give feedback

### On GitHub or in chat

Leave PR comments, then paste the review link into the agent chat and ask it to
address them. Or give feedback directly in chat: describe what feels wrong or show
what you want.

### In your editor

Put rough edits or voice-dictated notes beside the passage that needs attention.
An optional `Agent:` prefix distinguishes notes from finished wording.

1. Tell the agent you are editing and to keep the checkout read-only.
2. Leave your notes unstaged. Local edits and commits do not trigger GitHub CI;
   pushing to an open PR normally does.
3. Stop editing and hand over the files.
4. The agent backs up your notes outside the repository, applies the feedback,
   and validates the finished changes before pushing.
5. Resume editing when the agent hands the checkout back.

Take turns writing to the same checkout. With separate worktrees, hand over a
final diff for the agent to reconcile. Keep raw notes in the local backup.

### Revise earlier guidance and try again

If an attempt goes in the wrong direction, return to earlier human guidance,
adjust it, and ask for a fresh result. A **human attention checkpoint** records
that guidance and the code state it applies to. C1, C2, and later numbers identify
these points within one task; each appears on the PR with a name, guidance, and
code revision so you can tell them apart.

```text
Return to C2 — Parser direction. Keep the acceptance criteria, use the
existing parser, discard the abstraction, and retain the failing edge case.
```

C1 records your initial request. Later checkpoints record your steering or review;
an agent proposal, question, or passing check alone establishes none. Revised
steering gets a new checkpoint linked to the earlier one. Saying “Go” needs no
extra confirmation, and your Ask or Auto preference still applies.

The agent first preserves the rejected attempt and relevant uncommitted work.
By default, it adds a corrective commit to the existing branch to restore owned
code; newer commits remain in history. It then implements your revised guidance
with unrelated newer work and relevant findings preserved. If the snapshot is
incomplete or another writer is active, it explains the limitation before restoring.

The PR describes the active attempt and puts superseded work in expandable
summaries with published review links. Human comments remain intact. A final
squash merge leaves the resulting change on the base branch while the PR retains
the attempt history. Rewind does not undo deployments or other external effects;
the replacement still needs validation and review.

This is an agent procedure. See the [human attention checkpoint procedure](../skills/shaka/references/return-points.md)
for preservation rules and the real-use evaluation still needed.

## Resume unfinished work

You can leave a new request on any open PR, including one awaiting merge. Before merging, wait
for the agent to address it: make the change, explain why no change is needed, or
ask you to decide. When the agent resumes work, it removes `awaiting-merge-approval`.
It restores that label after handling the request and checking that the PR is ready again.

Read the handoff to find out whether automatic follow-up is active. The agent
starts it only when the coding tool can resume the owning chat after new feedback
arrives. A tool that resumes only when CI finishes is not enough.

With automatic follow-up active, Shaka checks GitHub every minute, even after CI
finishes. Each monitoring run lasts up to one hour. When a run expires, the agent
checks that it still owns the PR and starts another run if its coding tool can
still resume the chat. If it cannot, the agent hands off to a named person.
The agent writes the owning chat, current expiry time, and next action in the PR's
expandable **WIP Details** section, and updates them when monitoring restarts.
Keep that chat unarchived while monitoring depends on it.

If the handoff says **Automatic feedback intake unavailable**, it names the person
responsible for checking new feedback. That person opens the **Chat link** in WIP
Details and sends its resume prompt, for example `$shaka https://github.com/OWNER/REPO/pull/N`.
Do the same if the recorded expiry has passed without a renewed handoff. Leaving a GitHub comment alone does not
resume the agent in this case.

The Chat link works when the owning chat is reachable. In Codex,
`codex://threads/...` opens the original conversation. Before another agent takes
over, confirm the previous one has stopped or handed off; a timestamp cannot prove it.

To recover after a crash or in a new chat, paste the **Next action** from WIP Details,
such as `$shaka https://github.com/OWNER/REPO/pull/N`. The agent checks the live PR
before continuing. If no PR exists, supply the original task and checkout.
See [recovery limits](expected-experience.md#resume-or-change-your-checkout).

## Split a large change

Ask for independently useful changes as separate PRs. For example, a React on
Rails upgrade may need React 19: merge the React update first, then finish the
integration.

Each PR gets its own tests and review. The agent updates the remaining branch
after each prerequisite merges. The original chat owns the overall outcome;
no stacked-PR service is needed.

## Suggest improvements to Shaka

Tell your agent in chat what you would like Shaka to do better. For example:
“Shaka asks too many setup questions—can we simplify that?”

The agent helps refine the idea and asks before filing an issue.

## Find PRs waiting on you

| Search on GitHub | Your next action |
| --- | --- |
| `is:open label:awaiting-answer` | Answer the questions in the PR description. |
| `is:open label:awaiting-merge-approval` | Merge or approve the named commit under Ask. |
| `is:open label:awaiting-resume` | Paste the WIP Details next action into the agent chat. |

The agent manages these labels; a stopped agent can leave one stale.
See [approval and label details](pr-verification.md#approval-and-attention-labels)
when you need them.

## Squash with a useful commit message

For a squash merge, copy the title and body from the agent's last PR comment into
GitHub's merge boxes. See [squash merge details](pr-verification.md#squash-merge-details)
for repository defaults and automatic merges.
