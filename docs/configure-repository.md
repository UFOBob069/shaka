# Configure a repository

Use shared configuration when your team wants repository-wide settings. For a
local trial without a setup PR, see the
[individual-trial experience and limitations](expected-experience.md#individual-trials-available-tools-incomplete-guided-experience).
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
local validation and review, and you merge on GitHub. Auto merge needs at least one
required check.

## Set up

Connect your existing tools to Shaka:

```text
$shaka Configure this repository for Shaka. Reuse its existing setup,
test, and validation commands. Explain the review and merge choices.
Use merge policy ask.
```

The agent inspects your project, reads existing instructions, and prepares a
separate setup PR using your commands. You review the choices and **merge this
first setup PR yourself on GitHub** before starting feature work. Until it merges,
Shaka cannot use those proposed settings to choose a reviewer or merge for you.
The agent reviews the setup PR and names the commit for you to merge.

To change a choice later, ask:

```text
$shaka Configure this repository to wait for all configured CI reviewers.
Keep merge policy ask.
```

You do not need to edit configuration files by hand. Start with the
[settings guide](settings-guide.md); use the [reference](settings.md) when you
need exact options and defaults.

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

Repositories configured before this layout keep `.agents/agent-workflow.yml` and
`.agents/bin/`, and Shaka still reads them. Moving to `.agents/shaka/` is optional;
the [layout upgrade](https://github.com/shakacode/shaka/blob/main/skills/shaka/references/migration.md#upgrade-the-configuration-layout)
does it in one reviewed step.

Shaka's own [configuration](https://github.com/shakacode/shaka/blob/main/.agents/shaka/config.yml)
and [scripts](https://github.com/shakacode/shaka/tree/main/.agents/shaka/bin) provide working examples.
