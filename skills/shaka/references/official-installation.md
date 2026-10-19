# Official installation

Use this procedure for everyday installation, update, verification, or migration.
Require Ruby 3.4 or later, Git, and authenticated GitHub CLI; see
[prerequisite details](installation.md#prerequisites). Shaka records its own Ruby
and ignores project Ruby and Bundler settings. Never edit the dedicated checkout.

## Install

Review the source and installer, then clone into a directory outside the
repositories your agent will edit:

```bash
umask 022
mkdir -p "$HOME/.agents"
git clone https://github.com/shakacode/shaka.git "$HOME/.agents/shaka"
"$HOME/.agents/shaka/bin/install" --agent codex
```

Default: `~/.agents/shaka`; respect chosen locations with `--directory DIR`.
Use the registered helper to preserve an existing installation’s chosen path; the default applies to new installations.
Keep it for direct links and develop separately. `~/agent-tools/shaka` is an optional example.
This directory is the Shaka source, not configuration; each project keeps its settings in its own `.agents/shaka/`.

<a id="use-shaka-in-claude-code"></a>
<a id="use-shaka-in-cursor"></a>
<a id="use-shaka-in-opencode"></a>

| `--agent` | Skill links | Invocation |
| --- | --- | --- |
| `codex` (default) | `~/.agents/skills` | `$shaka` |
| `claude` | `~/.claude/skills` | `/shaka` |
| `cursor` | `~/.cursor/skills` | `/shaka` in a new Agent chat |
| `opencode` | `~/.config/opencode/skills` | `/shaka` in a new session |

Repeat `--agent` for several hosts, or use `--directory SOURCE --skills-dir DIR` for a custom directory.
Add `--with-mct` for the Codex master, `--with-rct` for its repository tower,
or `--with-claude-towers` for Claude towers. Codex flags are independent; both
may be selected. Default installation includes only Shaka.
If an older installer lacks a tower flag, update Shaka first, then run
`bin/install` to select that tower.
Use installer-owned or root-owned protected files and directories, without group
or world write access. Reinstallation preserves recognized towers and registered hosts. Start a new chat
and look for **Shaka**; restart the host if its list is stale. Tower flags apply
to every selected host; install hosts separately when their roles differ.
For an existing permission error, remove group/world write access from the named
paths you own, or select a protected location. Preserve file contents and executable bits.

## Verify and update

The installer prints an update reminder for every host and custom skills directory.

`update-check` compares the checkout's HEAD commit with its registered origin branch from any folder. `drift` means
the checkout moved; its guidance says whether `install --update` can record the move. An `unknown` result names its reason.
Use the registered helper with your chosen path:

```bash
"$HOME/.agents/shaka/skills/shaka/scripts/shaka" install --verify
"$HOME/.agents/shaka/skills/shaka/scripts/shaka" update-check
"$HOME/.agents/shaka/skills/shaka/scripts/shaka" install --update
```

Verification checks checkout identity, cleanliness, links, and Ruby without changes.
Update validates the fetched tree before advancing the recorded origin branch. Dirty tracked or untracked files, unexpected checkout changes,
and divergent updates stop it. After a manual pull of the registered branch,
`install --update` records the pulled revision; local commits still stop it. Preserve changes in a development checkout;
do not reset them to make installation succeed. Repair missing Ruby records by
running `bin/install` with Ruby 3.4 or later. Maintenance uses registered selections;
change hosts or towers through installation first. A known interrupted update
completes on the next installation or update run.

Finish active Shaka chats before updating this mutable path. Doctor reads recorded identity;
verification rechecks it. Project settings use [repository migration](migration.md).

## Migrate retained-copy installations

When the user selects migration:

1. Select the dedicated directory. Clone the current official source there, or
   bring an existing clean, expected checkout to the current default branch before
   first registration. Stop for local changes or an unexpected remote.
2. Run its new `bin/install --directory DIR` with every selected `--agent`, or
   the original custom `--skills-dir`. Recognized tower links migrate too.
3. Run its helper's `install --verify` and confirm Shaka in a new chat.

Canonical Codex installation retires verified `~/.codex/skills` aliases after
`~/.agents/skills` links succeed. This covers the standard managed directory
and selected checkout; inspect other duplicates and preserve intentional trials.
Keep every older package: active chats may reference its absolute paths.

## Teams and forks

Use the [fork guide](https://github.com/shakacode/shaka/blob/main/docs/fork-and-hack.md).
Keep local `.git` installation records per machine. For forks or SSH origins, register the exact `--repository URL` and optional `--branch NAME`.
Publish upstream integrations separately before updating.

## PR trials and retained copies

Use [PR trials](https://github.com/shakacode/shaka/blob/main/docs/trying-pr-versions.md)
for intentional evaluation without replacing the default links.
`--skills-dir DIR` alone preserves the [legacy managed-copy procedure](installation.md).
Keep all retained copies; this migration authorizes no deletion or automatic cleanup.
