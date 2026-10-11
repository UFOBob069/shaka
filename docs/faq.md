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

Individual setup tools exist, but a seamless new-user delivery remains unproven.
Read the [individual-trial limitations](expected-experience.md#individual-trials-available-tools-incomplete-guided-experience)
before choosing that path. Trying an unmerged version of Shaka is a separate option:
see [try a Shaka PR](trying-pr-versions.md).

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

## Why does Shaka review with a separate CLI instead of a subagent?

A separate CLI is more independent of the agent that wrote the change, and it
leaves a record. The coding agent could ask a subagent on its own host to review,
but Shaka does not count that as the local review.

| | Separate reviewer CLI | Subagent on the same host |
| --- | --- | --- |
| Who writes the prompt | Shaka's helper; your review criteria come from the default branch | The agent whose work is under review |
| Where it runs | An empty directory, with no edit access and without the checkout's instructions, skills, or hooks | The PR's checkout, with the host's tools and instructions |
| Provider | Can differ from the one that wrote the change | The host's provider |
| What it leaves | An exit status and a report naming the reviewed commit; Codex and Claude also leave a usage record | Text returned to the coding agent; its tokens count with the coding session |

The trade-off is reach. The Codex and Grok reviewers can read other files at the
reviewed commit, and the Claude reviewer sees only the diff. A subagent could read
the whole checkout and run its tests.

The agent follows this as an instruction. `shaka merge` checks that a review of the
commit was published, not which process wrote it. See
[what Shaka enforces](#what-does-shaka-enforce-and-what-relies-on-the-agent).

## Why did the agent ignore a PR comment?

Shaka trusts the people who maintain the project: anyone with write access, plus
the users, bots, and teams listed in `.agents/trusted-github-actors.yml` or your
machine's allowlist. On a public repository, anyone else can comment, and that
text could try to steer the agent. The agent withholds those comments and keeps
their links for you to read. See
[configure trusted actors](../skills/shaka/references/public-comments-safety.md#configure-trusted-actors).

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

Yes. In your [settings](settings.md) file, set
[`review.prompt_file`](settings.md#reviewprompt_file) to the path of a Markdown
file, relative to the repository root, such as `.agents/review-prompt.md`. It
replaces Shaka's default instructions for what the local reviewer looks for and
how it reports. To give one review agent different instructions, set
`prompt_file` on that agent's entry in `local_review_agents`. Copy Shaka's
[default instructions](../skills/shaka/config/review-prompt.md) to start.

The agent reads the file from the default branch when it runs
`shaka review run --criteria-ref`, so a PR that edits it is reviewed with the
current version. Criteria in `AGENTS.md` still apply on top of the prompt file.
The prompt file configures local reviews; a CI review job takes its prompt from
its own workflow.

A few rules stay whatever the file says, because they are protocol rather than
policy. For example, the closing `REVIEWED` line lets `shaka review run` confirm
which commit was reviewed. The [settings](settings.md#reviewprompt_file) list
them all.

## Can a PR change Shaka's settings or rules for itself?

Not until it merges. Settings and review criteria come from the default branch,
so each PR is reviewed under the rules its maintainers already agreed on, and a
PR from a fork cannot change how it is reviewed. Until it merges, Shaka reviews a
settings change as part of the diff. See [settings](settings.md).

## What does Shaka enforce, and what relies on the agent?

Ruby checks settings and trusted comment authors. When the agent merges, it also
checks the reviewed commit and, when review is required, that posted review
covers it or that a reason for skipping review was given. How thorough that review
was, test quality, screenshots, and privacy rely on the agent's judgment. See
[what is enforced](workflow.md#what-is-enforced).
