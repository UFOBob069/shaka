# Configure a repository

Use shared configuration when your team wants repository-wide settings. For a
setup just for you without a setup PR, see
[individual setup](expected-experience.md#individual-setup).
The procedures below publish team configuration.

## Use Shaka across projects

Use the same skill across your organization’s repositories or the open-source
projects you maintain. Each repository chooses its checks, reviewers, and merge
policy through a small configuration boundary, called the **seam**.

For example, a library can use its Ruby test suite and require your merge approval,
while a documentation project uses link checks and allows Auto after required
checks and reviews. Updating the shared skill keeps these project choices in
repository configuration; you do not need a separate copy of the workflow for each.

Use [Choose your settings](settings-guide.md) to decide what suits your team.

## Before you start

Shaka waits for your CI checks before it calls a PR ready, and before it merges one
in Auto mode. It uses the checks GitHub requires on your default branch through a
ruleset or branch protection. When GitHub requires none, as on any private
repository on the GitHub Free plan, list them in
[`merge.required_checks`](settings.md#mergerequired_checks) instead.

Setup works this out for you. To see where you stand first:

```text
$shaka Which CI checks does GitHub require on this repository's default branch?
If none, which check names appear on recent PRs?
```

A repository with no required checks can still use Shaka in Ask mode: the agent runs
local validation and review, then you merge on GitHub or tell the agent to merge
that commit. Auto merge needs at least one required check, because nothing else
would gate an unattended merge.

## Set up

Connect your existing tools to Shaka:

```text
$shaka Set up Shaka for this repository.
```

The agent finds your test and lint commands, explains AI review choices, and keeps
merge policy Ask. It prepares a separate setup PR using your commands.
Review the choices and **merge this first setup PR yourself on GitHub** to make
them the team's defaults. The agent reviews it and names the commit for you to merge.
To try the choices on one task first,
[select that settings PR](settings.md#preview-settings-before-adopting-them).

To change a choice later, ask:

```text
$shaka Wait for all configured CI reviewers.
```

You do not need to edit configuration files by hand. Start with the
[settings guide](settings-guide.md); use the [reference](settings.md) when you
need exact options and defaults.

## Add hosted Claude review

Shaka ships a [Claude review workflow](https://github.com/shakacode/shaka/blob/main/skills/shaka/config/claude-code-review.yml)
that reviews PRs opened from branches in your repository, and fits teams where only
some people use Shaka. It skips drafts, Dependabot, and PRs from forks; review those
another way.
When a PR's author already published a Shaka local review of the pushed commit
with Claude among its reviewers, Claude makes a short pass for serious bugs the
local reviewers missed. Every other PR gets a full review, including one only
Codex reviewed locally. Both report only issues Claude can tie to a concrete failure,
so routine pushes stay quiet.

During [setup](#set-up), the agent offers it. For a repository that already uses
Shaka, ask:

```text
$shaka Add the hosted Claude review workflow from
https://github.com/shakacode/shaka/blob/main/skills/shaka/config/claude-code-review.yml
and list claude-review as a CI review job.
```

The agent adds the workflow and lists the `CLAUDE_CODE_OAUTH_TOKEN` repository
secret you need to create. The workflow waits up to two minutes for the local
review before choosing the full review; edit `LOCAL_REVIEW_WAIT_SECONDS` in it to
change that. Only the PR author's own comment selects the short pass, so another
person's comment cannot weaken review of someone else's PR.


## Files the agent prepares

The configuration records project choices; the scripts connect existing checks;
the comment allowlist identifies whose public comments the agent may read.
This inventory is useful when
reviewing the setup PR.

| File | Purpose |
| --- | --- |
| `.agents/shaka/config.yml` | Review, merge, branch, and WIP settings |
| `.agents/shaka/bin/setup` | Install project dependencies |
| `.agents/shaka/bin/test` | Run tests; accept focused test arguments |
| `.agents/shaka/bin/validate` | Run the complete pre-PR checks |
| `.agents/shaka/bin/validate-local` (optional) | Run a faster local check before review |
| `.agents/shaka/bin/trigger-hosted-ci` (optional) | Start deferred CI after local fixes; requires `validate-local` |
| `.agents/shaka/trusted-github-actors.yml` | Whose public GitHub comments the agent may read |
| `.agents/shaka.md` | Pointer to this configuration for people browsing the repository |
| `AGENTS.md` (optional) | Existing project instructions and constraints; Shaka does not create or edit it |

The scripts usually wrap existing commands. In Shaka's repository, `.agents/shaka/bin/setup`
installs development dependencies; `bin/install` installs the skill.

Shaka's own [configuration](https://github.com/shakacode/shaka/tree/main/.agents/shaka)
provides working examples of the required files.
