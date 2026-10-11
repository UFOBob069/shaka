# Frequently asked questions

## What should I try first?

Pick a small bug or improvement in a project you know. Follow [Start here](getting-started.md)
to install Shaka, ask the agent to configure the repository, and run your task.
[Working with Shaka](working-with-shaka.md) explains the PR you get and your merge decision.

## Do I need to write configuration by hand?

No. Ask the skill to inspect your project and reuse its existing checks.
For shared setup, review the agent's choices and merge the initial setup PR yourself.
See [repository setup](configure-repository.md).

## Can I try it without changing team configuration?

Yes, if the repository has no shared Shaka settings:

```text
$shaka <task or issue link>
Set up Shaka just for me. Go.
```

Settings stay out of commits. See [individual support and acceptance gaps](expected-experience.md#individual-setup).
With team settings, local choices do not override them. You can explicitly
[select a settings PR](settings.md#preview-settings-before-adopting-them) for one task,
as shipped in [#426](https://github.com/shakacode/shaka/pull/426).
Trying a different Shaka implementation is separate: see [try a Shaka PR](trying-pr-versions.md).

## Why did the agent stop to ask about model and effort?

Before it changes code, Shaka recommends a model and effort for the task.
“Go” without naming either accepts your agent's current settings, even when
they differ from the recommendation or cannot be reported. If you name either
setting, Shaka pauses when the settings are unavailable, unverified, or differ
from its recommendation. See [give it an outcome](working-with-shaka.md#give-it-an-outcome).

## Why didn't the agent merge my PR?

Under **Ask**, the default, the agent labels the PR `awaiting-merge-approval` and
names the commit to merge. Merge it on GitHub, or approve that commit and the
agent merges it. Under **Auto**, a PR
past the [size limits](settings.md#mergelimits), or one that changes trust,
authentication, releases, or other consequential areas, still comes back to you.
See [choose a merge policy](working-with-shaka.md#choose-a-merge-policy).

## Does a green review job mean the PR was reviewed?

No. A job can pass without producing a review. The agent reads the report and
counts only one that covers the current commit. See
[`review.ci_review_jobs`](settings.md#reviewci_review_jobs).

## Can the agent review its own work?

It prefers a reviewer from a different provider, in the order set by
[`review.local_review_agents`](settings.md#reviewlocal_review_agents). Next it
uses a listed reviewer from the same provider. When no listed reviewer is
available, a fresh session with the implementation model reviews the change
without the implementation conversation.

<a id="why-does-shaka-review-with-a-separate-cli-instead-of-a-subagent"></a>

## Why does Shaka use a separate review session?

A fresh session reviews without the implementation conversation. This supplies
another perspective, without guaranteeing quality. Shaka uses a restricted CLI
or its supported API adapter and records the reviewed commit, findings, and
available usage. It does not count a same-host subagent as the local review.

Reviewers have different access to unchanged code. See
[reviewer choices and limits](settings.md#reviewlocal_review_agents) and
[what Shaka enforces](workflow.md#what-is-enforced).

## Do multiple reviews run one after another?

The agent runs them concurrently and combines their findings before repairs.
Additional reviewers add cost and may increase elapsed time.
See [reviewer count](settings.md#reviewlocal_review_count).

## Why did the agent ignore a PR comment?

Shaka trusts the people who maintain the project: anyone with write access, plus
the users, bots, and teams listed in `.agents/shaka/trusted-github-actors.yml` or your
machine's allowlist. On a public repository, anyone else can comment, and that
text could try to steer the agent. The agent withholds those comments and keeps
their links for you to read. To change the allowlist, ask:

```text
$shaka Add USER to this project's trusted GitHub actors.
```

## Where do I put project rules?

| What | Where |
| --- | --- |
| Commands, merge policy, and review jobs | [Settings](settings.md) in `.agents/shaka/config.yml` |
| Project constraints, review criteria, and writing style | `AGENTS.md` |
| What the local reviewer looks for and how it reports | [`review.prompt_file`](settings.md#reviewprompt_file), replacing Shaka's defaults |
| Changes to Shaka's workflow | A [fork of Shaka](workflow.md#customize-the-instructions) |

Keep `AGENTS.md` a regular file with the instructions in it; Shaka reads it from
Git at the trusted commit. Recent Claude Code versions can read `AGENTS.md`
directly, but not in every session, and not by default when a `CLAUDE.md` exists.
To give Claude the same instructions every time, add a `CLAUDE.md` containing
`@AGENTS.md` rather than a symlink. See Claude Code's
[AGENTS.md support](https://code.claude.com/docs/en/memory#agents-md).

## Can I customize the prompt Shaka gives its local reviewer?

Yes, through shared settings. In your [settings](settings.md) file, set
[`review.prompt_file`](settings.md#reviewprompt_file) to the path of a Markdown
file, relative to the repository root, such as `.agents/review-prompt.md`. It
replaces Shaka's default instructions for what the local reviewer looks for and
how it reports. To give one review agent different instructions, set
`prompt_file` on that agent's entry in `local_review_agents`. Copy Shaka's
[default instructions](../skills/shaka/config/review-prompt.md) to start.

Shaka reads the default-branch version, so a PR that edits it is reviewed with the
current version. Individual custom instructions are not applied yet;
[#481](https://github.com/shakacode/shaka/issues/481) tracks this gap.
Criteria in `AGENTS.md` still apply on top of the prompt file.
The prompt file configures local reviews; a CI review job takes its prompt from
its own workflow.

The [settings reference](settings.md#reviewprompt_file) explains which instructions
apply and links the review protocol.

## Can a PR change Shaka's settings or rules for itself?

Editing settings in a PR does not select them automatically. Shared settings and
review criteria normally come from the default branch. A maintainer can explicitly
[select a settings PR's pinned configuration](settings.md#preview-settings-before-adopting-them)
for experiments. A fork PR cannot choose its own review rules. See
[which settings apply](settings.md#which-settings-apply).

## What is a decision checkpoint?

It helps the task owner choose what to do next. See the
[decision-checkpoint guide](pr-verification.md#decision-checkpoint) for its terms,
how it differs from the code walkthrough, and current report labels.

## Can I hide my checkout path while keeping the chat locator?

Currently, `wip.include_locations: false` hides both. [#482](https://github.com/shakacode/shaka/issues/482)
tracks independent checkout-path visibility. A chat locator helps resume the
owning chat; its access rules depend on the host. See [WIP settings](settings.md#wipinclude_locations).

## What does Shaka enforce, and what relies on the agent?

Ruby checks settings and trusted comment authors. When the agent merges, it also
checks the reviewed commit and, when review is required, that posted review
covers it or that a reason for skipping review was given. How thorough that review
was, test quality, screenshots, and privacy rely on the agent's judgment. See
[what is enforced](workflow.md#what-is-enforced).
