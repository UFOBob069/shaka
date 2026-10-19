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
day on `main` does not interrupt every new chat. Finish active Shaka chats,
fetch and apply it, then start a new chat:

```bash
"$HOME/.agents/shaka/skills/shaka/scripts/shaka" install --update
```

The update stops without changing the checkout when it finds local changes or
history that diverged from the recorded branch. To read an update before you
apply it, run `git fetch` in the checkout and compare `HEAD` with the recorded
branch, which is `origin/main` unless you chose another.
