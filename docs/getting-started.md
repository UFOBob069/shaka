# Start here

Give your coding agent a task. Shaka guides it through implementation, checks,
independent review, and a pull request you can understand and decide whether to merge.
Start with a small fix in a project you know.

Examples use `$shaka` in Codex. Use `/shaka` in Claude Code, Cursor, or OpenCode;
in Pi, load the installed Shaka skill. See [coding agents](coding-agents.md).

<a id="getting-started"></a>

## 1. Install Shaka

Ask your coding agent:

```text
Install Shaka from https://github.com/shakacode/shaka.
```

Prefer to run the commands yourself? Follow [manual installation](manual-installation.md).

The agent checks for Ruby 3.4 or later, Git, and an authenticated GitHub CLI.
It installs one dedicated checkout outside your projects and links the skill
directly into it. The default location is `~/.agents/shaka`; you can
choose another directory, such as `~/agent-tools/shaka`.

The installer adds a `shaka` link and an empty lock file to your coding agent's
skills folder, such as `~/.claude/skills` for Claude Code. Your agent finds Shaka
through that link, so allow it if your rules protect that folder. See
[what the installer changes](manual-installation.md#what-the-installer-changes)
for everything it touches.

Keep the installation outside your project repositories. Use separate checkouts
for development so the installation stays ready for updates.

The skill prompts you when an update is available. Ask your agent to
[update Shaka](migration.md).

Start a new chat if the skill does not appear. Use a source installation: the published gem is a
name-reservation prerelease without the current workflow.

Try `$shaka` without a task for a guided welcome and setup check. Or ask:

```text
$shaka doctor
```

Doctor reports what is ready, which supported reviewer CLIs are on PATH, and
where to install missing ones. It gives setup advice even before this repository
is configured. Finding a CLI does not verify sign-in, quota, or a working review.
An extra provider can supply independent review; installing every CLI is optional.
The diagnostic changes no settings. It exits with status 1 when any check reports
FAILED; read the full report, since piping it through another command can hide
that status.

Set `SHAKA_MACHINE_ALIAS` in your shell profile to a short name such as `mini`.
An unfinished PR shows it as the owner, so you can tell which machine holds the
work; without it, the owner reads UNKNOWN. PRs may be public, so do not use the
machine's own name.

Give the agent a task when you are ready.

<a id="2-choose-private-trial-or-team-setup"></a>
<a id="2-choose-individual-trial-or-team-setup"></a>

## 2. Choose individual or team setup

Open a chat in your project and give Shaka a task:

```text
$shaka <task or issue link>
```

If Shaka is not configured, the agent asks which setup you want. **Individual
setup** keeps settings out of commits in a project without team settings.
To choose it upfront:

```text
$shaka <task or issue link>
Set up Shaka just for me. Go.
```

The agent finds your test and lint commands, explains AI review choices, and
defaults to Ask. Individual setup continues into the task without a team setup PR.
Host permissions may require approval for protected Git writes. See
[individual support and acceptance gaps](expected-experience.md#individual-setup).

For shared team settings, ask:

```text
$shaka Set up Shaka for this repository.
```

The agent prepares shared settings and scripts in a **setup PR**. They connect
Shaka to your project's commands and record its review and merge choices.
**Review the choices and merge this first setup PR yourself on GitHub.**
To try its settings before adoption, [select the settings PR for a task](settings.md#preview-settings-before-adopting-them).
If the repository is already configured, skip this step.
You can ask the agent to change settings later; you do not need to maintain them by hand.
See [repository setup](configure-repository.md) for details.

After merging shared reviewer settings, check whether your signed-in AI CLI
accounts can run the selected reviewer models and effort levels. This catches
account or model-access problems before the agent reaches code review. Ask:

```text
$shaka Probe this project's configured reviewers.
```

This live probe may consume quota or cost money. It keeps your chosen settings.
The agent sends each supported configured reviewer one short prompt and reports
which attempts succeeded. If an attempt fails, it explains the problem and asks
you how to proceed.

## 3. Start a task

```text
$shaka Fix search when the query contains an apostrophe. Go.
```

Replace the example with a small outcome or an issue link. `Go` lets the agent
start with its current model and effort settings. It handles routine work and
asks when a missing choice, access problem, or consequential decision needs you.

For a different outcome, choose an example:

- [Plan before implementing](working-with-shaka.md#get-a-plan-before-implementing).
- [Review an existing PR](working-with-shaka.md#review-an-existing-pr).
- [Resume a PR](working-with-shaka.md#resume-a-pr-you-already-started) or
  [recover unfinished work](working-with-shaka.md#resume-unfinished-work).
- [Set up a repository for your team](working-with-shaka.md#configure-a-repository-for-your-team).

Look for a PR explaining what changed, what was tested and reviewed, and any
remaining gaps. With **Ask**, you decide whether to merge; **Auto** lets the agent
merge after the required checks, review, and approvals.
Independent opening-check choices shipped in [#425](https://github.com/shakacode/shaka/pull/425)
after #420. [Merged #426](https://github.com/shakacode/shaka/pull/426) added
[settings previews](settings.md#preview-settings-before-adopting-them).
[Working with Shaka](working-with-shaka.md) covers these choices, useful prompts,
feedback, and resuming a task.

### Use a personal fork

To customize Shaka and contribute improvements upstream:

```text
Fork https://github.com/shakacode/shaka and install my fork.
```

For later maintenance, ask the agent to [upgrade your installation](migration.md).
To evaluate an unmerged workflow change, [try a Shaka PR on real work](trying-pr-versions.md).
