# Update Shaka

Shaka instructs your agent to check for updates and tell you when one is available.
Finish active Shaka chats, then ask:

```text
Update my Shaka installation.
```

Start a new chat after updating.

An installation from your own fork updates that fork's branch. It does not
pull upstream by itself. Bring upstream changes in by
[syncing the fork](fork-and-hack.md#keep-your-fork-current) first.

## Upgrade a repository's configuration layout

Older repositories keep Shaka's settings in `.agents/agent-workflow.yml` and its
commands in `.agents/bin/`. Shaka still reads that layout. To move it to
`.agents/shaka/`, ask:

```text
Upgrade this repository's Shaka configuration layout.
```

Your agent first shows a read-only preview. It lists every file to move, each
script to repair, repository-local symlinks, CI and guide references to update,
and anything that blocks the upgrade. Nothing changes until you approve the whole
preview. The upgrade command refuses to apply while any blocker remains, or when
files changed after the preview; the agent then previews again.

The upgrade keeps your settings, script modes, and command arguments. Repaired
scripts find the repository root with Git instead of counting parent directories.
Unrelated tools in `.agents/bin/` stay where they are. The upgrade command runs
none of your repository's scripts, so check the result and run your validation before
committing. Merge it in its own PR; until then, Shaka keeps reading settings from
your default branch.

If the upgrade is interrupted, ask your agent to recover it. The recovery command
restores only the files that upgrade recorded. It refuses to overwrite a file you
edited after the interruption, so you repair that file by hand.
