# Install Shaka manually

Run the installation yourself when you want to read what will run before it
runs. You need Ruby 3.4 or later, Git, and an authenticated
[GitHub CLI](https://cli.github.com/). To let your coding agent do this instead,
use the [installation prompt](getting-started.md).

## What the installer changes

Shaka installs as one Git checkout that you keep only for Shaka, outside the
repositories your agent edits. The installer, [`bin/install`](https://github.com/shakacode/shaka/blob/main/bin/install),
is a Ruby script that uses only Ruby's standard library. It makes these changes:

- **Skill links.** It adds a `shaka` symbolic link in your coding agent's skills
  directory, pointing into the checkout. Nothing is copied.
- **Installation records.** It writes the checkout's origin, branch, and selected
  agents, plus the path of the Ruby that ran it, inside the checkout's `.git`
  directory. Shaka then runs with that Ruby in every project.
- **Older Codex links.** For Codex, it removes a `shaka` link from
  `~/.codex/skills` when that link points at this checkout or at a Shaka copy an
  earlier installer made. It leaves every other entry alone.
- **Lock files.** It leaves an empty `.shaka-install.lock` file in each skills
  directory it links.

It does not use `sudo`, edit your shell profile or `PATH`, or install gems.
It refuses a checkout or skills directory that other accounts can write to.

Afterward, each Shaka command adds a line to a timing log at
`~/.local/state/shaka/calls.jsonl`. The log stays on your machine and holds no
arguments, paths, or task text. Set `SHAKA_CALL_LOG=off` to stop recording.

## Install

Clone the source. To install somewhere else, such as `~/agent-tools/shaka`,
change `SHAKA_DIR` on the first line:

```bash
SHAKA_DIR="$HOME/.agents/shaka"
umask 022
mkdir -p "$(dirname "$SHAKA_DIR")"
git clone https://github.com/shakacode/shaka.git "$SHAKA_DIR"
```

Read the source and `bin/install`, then run the installer in the same terminal.
It records the first `ruby` on your `PATH`, and `--directory` makes it register
the checkout you just read:

```bash
"$SHAKA_DIR/bin/install" --directory "$SHAKA_DIR" --agent codex
```

Replace `codex` with your coding agent, and repeat `--agent` to select several.
Each one adds this link:

| `--agent` | Skill link |
| --- | --- |
| `codex` | `~/.agents/skills/shaka` |
| `claude` | `~/.claude/skills/shaka` |
| `cursor` | `~/.cursor/skills/shaka` |
| `opencode` | `~/.config/opencode/skills/shaka` |

Pi has no option of its own; it loads the shared skill linked for `codex`.
`bin/install --help` lists the remaining options.

Start a new chat and look for **Shaka**. [Coding agents](coding-agents.md) shows
how to start a task in each one. Then continue with
[setup](getting-started.md#2-choose-individual-or-team-setup).

## Install your own fork

The commands above install ShakaCode's repository. To run a version you can
change, follow [Fork Shaka and make it yours](fork-and-hack.md). Pass
`--repository` with your fork's exact origin URL.

## Verify and update

Check the installation at any time, using the directory you installed into.
This command changes nothing in the checkout or your skill links:

```bash
"$HOME/.agents/shaka/skills/shaka/scripts/shaka" install --verify
```

It confirms that the checkout comes from the recorded origin, has no local
changes, and is the target of each skill link, and that the recorded Ruby still exists.

Shaka tells you when an update is available once your installation is three
commits behind, or when the oldest change you lack is a day old, so a busy
day on `main` does not interrupt every new chat. Each `update-check` answer is
saved in `~/.local/share/shaka/update-check.json`. Any later Shaka command reads
that file, without a network request, and prints one line to standard error at
most once a day when it says to update, says the checkout moved, or is missing or over a day old.
A command run from a different Shaka checkout than your skill links point to
prints one line naming the linked one. Set `SHAKA_NOTICES=off` to silence both.

To have each new Claude Code chat start with the saved answer, add `--session-hook`
to `bin/install --agent claude`. The chat then hears about an update, a moved
checkout, or a check over a day old, without a network request that would slow
its start. That adds one `SessionStart` hook to `~/.claude/settings.json`;
installing with `--agent claude` again without the flag removes it.

When an update is due, finish active Shaka chats, fetch and apply it, then start a new chat:

```bash
"$HOME/.agents/shaka/skills/shaka/scripts/shaka" install --update
```

The update stops without changing the checkout when it finds local changes or
history that diverged from the recorded branch. To read an update before you
apply it, run `git fetch` in the checkout and compare `HEAD` with the recorded
branch, which is `origin/main` unless you chose another.

## Develop Shaka in a separate clone

Your coding agent runs Shaka straight from the folder you installed, so keep
that folder for Shaka alone. If you also work on Shaka, do it in a second clone.

The installer stops when the folder:

- is a Git worktree. Worktrees are often deleted after their branch merges, and
  Shaka would disappear with it.
- has other branches or worktrees. `install --verify` and `install --update`
  only warn about these.

### Move Shaka out of a clone you develop in

Run this inside the clone you develop in. It makes a fresh clone for Shaka and
points your coding agents at it:

```bash
./bin/install --directory ~/.local/share/shaka/source --take-over
```

Your old clone keeps its files, branches, and worktrees; it only stops being
the installed copy. If the move fails partway, your agents keep using the old
clone, and the installer lists anything it could not put back. When you run the
command from a different clone and your skills live in a custom folder, add
`--skills-dir DIR`.

If the installer is force-stopped (`kill -9`) at the wrong moment, no clone
counts as installed. To fix it, rename the newest
`.git/shaka-install.retired-*.json` in the old clone to
`.git/shaka-install.json`, then run the command again.
