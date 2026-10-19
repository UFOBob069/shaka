# Retained-copy installation

Use [official installation](official-installation.md) for everyday install, update,
verification, and migration. Use this procedure only for an intentional retained copy.
Examples below use the optional `~/agent-tools/shaka` convention; respect chosen locations.
The [getting started guide](https://github.com/shakacode/shaka/blob/main/docs/getting-started.md) supplies the prompts.
Use source installation: the published name-reservation gem
predates the current workflow. Confirm the requested source, version, and coding
environment before installation. Preserve existing customizations during updates.
Shaka is the successor to `shakacode/agent-workflows`; new installations need only
this repository.

## Prerequisites

You need Ruby 3.4, Git, an authenticated [GitHub CLI](https://cli.github.com/), and
a [supported coding agent](installation.md#development-environment-details).

```bash
git --version
ruby --version
gh auth status
```

Use `gh auth login` if you are not signed in.

Shaka keeps its own Ruby, separate from your projects. The installer records the
Ruby that runs it, and the installed `scripts/shaka` starts with that Ruby in every
project. It also ignores a project's `RUBYOPT`, Bundler setup, and installed gems,
because Shaka needs only Ruby's standard library. Run the installer where
`ruby --version` reports 3.4 or later; an older Ruby stops with that requirement.
If that Ruby or its record is removed, `scripts/shaka` stops and asks you to
install again or set `SHAKA_RUBY` to another Ruby 3.4 interpreter. Without a
registered installation or managed package, `scripts/shaka` uses `ruby` from `PATH`.

Optional: [ImageMagick 7](https://imagemagick.org/script/download.php) can draw
[annotations and pixel diagnostics](visual-diff.md). Check it with `magick --version`.
Agents can also use an existing editor or browser overlay; ImageMagick is not required.

## Install

Review the source and installer, then clone into a directory outside the
repositories your agent will edit:

```bash
mkdir -p "$HOME/agent-tools"
git clone https://github.com/shakacode/shaka.git "$HOME/agent-tools/shaka"
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.agents/skills"
```

The installer copies the skill to `~/.local/share/shaka/installs/` and links Codex
to that managed copy. The source checkout can then be removed; select a source
checkout again when upgrading or rolling back. Open a new task in
your project and look for
`$shaka`; restart Codex if it does not appear.
Codex lists managed copies as `Shaka VERSION (COMMIT)`, using a short commit for
an exact revision or `dev CONTENT` for a development copy. The invocation remains
`$shaka`. A source checkout keeps its own display name. Installing into two skills
directories that Codex reads can show both entries, even when both are named `shaka`.
Links to public guides show the current documentation. When using an older package
or rolling back, follow its installed workflow and the repository's trusted seam
if a public guide describes newer behavior.
If the source sits inside another Git repository whose ignore rules match skill
files, move it to a standalone checkout before installing.
Use `--managed-dir DIR` if the default package location is unsuitable. Choose a
directory outside project checkouts and pass the same directory on upgrades and
rollbacks.

<a id="use-shaka-in-claude-code"></a>
<a id="use-shaka-in-cursor"></a>
<a id="use-shaka-in-opencode"></a>
## Other development environments

Use the same installer with your environment's skills directory:

| Environment | `--skills-dir` | Invocation |
| --- | --- | --- |
| Claude Code | `"$HOME/.claude/skills"` | `/shaka` |
| Cursor | `"$HOME/.cursor/skills"` | `/shaka` in a new Agent chat |
| OpenCode | `"$HOME/.config/opencode/skills"` | `/shaka` in a new session |

Keep the managed copy and links outside directories the coding agent can edit
during project work, including project checkouts. If the agent can write the
default home location, choose a protected managed directory and run installation
with the needed privileges. The installing account must own its source checkout
or have that checkout trusted by Git; a separate account can use its own clone.
Make the package path readable by the coding agent,
and use the same installing account for upgrades and rollbacks so it can open the
host skills directory's lock file. Protect the managed directory from untrusted writers; its
metadata records identity but does not authenticate who created a package. See
[environment details](#development-environment-details) for terminal launchers, Pi, Cursor usage hooks,
and tested limitations.

The installer creates new managed and host skills directories with mode `0755`.
It refuses either directory if group or world writable. It also refuses a
directory or ancestor owned by an account other than the installer or root;
a writable ancestor is accepted only with a sticky bit and a child owned by
the installer or root. For example, an existing `0775` skills directory
created under umask `002` must have group write removed or be replaced with a
protected directory. The error names the path and the rule it broke; use
`--managed-dir DIR` if the default package path is unsuitable. When the error
says a sandbox or container is hiding the real owner, run the installer from a
terminal outside it.

## Install from a personal fork

When the user requests a fork, create or select it on GitHub and install it as the
dedicated checkout in [official installation](official-installation.md), not a
retained copy. Clone it into the installation directory, set `origin` to their fork
and `upstream` to `https://github.com/shakacode/shaka.git`, and inspect both remotes
before updating. When Shaka is already installed there, do not clone or install a
second checkout: rename its `origin` to `upstream` and add the fork as `origin`.
Create and push a dedicated branch, such as `mine`, so the fork's `main` can match
upstream. Then run `bin/install --directory DIR --repository URL
--branch BRANCH --agent HOST`, where `URL` is the exact `origin` URL and `BRANCH`
is that dedicated branch.

For updates, fetch upstream and inspect the diff. Fast-forward when possible;
otherwise preserve fork changes while merging or rebasing on a feature branch.
Validate the result, then merge it into the installed branch; `install --update`
only fast-forwards, so never rewrite that branch. Contribute improvements
through a branch and PR to upstream when the user authorizes that publication.
Never overwrite local customizations to make an update succeed.

## Configure a repository

After installing, follow [repository setup](repository-setup.md), then run
`shaka doctor --root /path/to/repository` from the trusted installed helper.
Resolve failed checks before publishing work.
`shaka doctor --installation-json` prints the installed version, package ID, and
source identity without checking a repository. A source records an exact revision
only when it is the repository root, its selected file set matches `HEAD`, its
selected paths have clean Git status, the file bytes and executable modes match
`HEAD`, each selected directory contains a tracked file, and no selected file is
world-writable. A Git-clean checkout with converted line endings can therefore
record a development installation. Development installations record a base
revision when available and a content hash. The managed copy removes group and
world write access.
Doctor reports the identity recorded at install time; it does not recheck the
package's contents or compare the recorded revision with Git on each run.
Protect the managed directory because these labels come from its metadata.

## Upgrade

Inspect and preserve local changes in the trusted checkout, then fast-forward:

```bash
git -C "$HOME/agent-tools/shaka" status --short
git -C "$HOME/agent-tools/shaka" switch main
git -C "$HOME/agent-tools/shaka" pull --ff-only
```

Run `bin/install` from the chosen source with your original `--skills-dir` and
optional tower flags. It validates a new managed copy before switching the links.
Existing tasks that use the host link may pick up the new helper after the switch.
Finish or pause them before upgrading, then start a new task with the new skill.
The previous package remains in the managed directory you chose, which defaults
to `~/.local/share/shaka/installs/`.
If an existing link points to a different or deleted checkout, or an older gem,
the installer refuses to replace it. Inspect that link first; if it is an old
Shaka installation you intend to replace, unlink only that Shaka skill link and
rerun `bin/install`. Preserve unrelated files and links.
Configuration changes may also require a repository migration.
If an unchanged-source reinstall refuses a changed package, move only that
package directory aside and rerun the installer to create a fresh copy.

To roll back, read the previous package ID from the installer's `Package:` line
or from `shaka doctor --installation-json` before upgrading, then run:

```bash
"$HOME/agent-tools/shaka/bin/install" --skills-dir "$HOME/.agents/skills" --rollback PACKAGE_ID
```

If you installed with `--managed-dir DIR`, add the same option and directory to
this rollback command.

Include the optional tower flags recorded in that package. If the current install
has tower skills that the rollback package lacks, inspect and unlink those managed
tower links first. The installer refuses a missing package or one whose contents
do not match its own metadata. It does not independently prove who created a
package in the managed directory.

## Remove

Inspect the link first and confirm it points to a managed Shaka package:

```bash
ls -l "$HOME/.agents/skills/shaka"
```

Then remove that link:

```bash
unlink "$HOME/.agents/skills/shaka"
```

Use the appropriate directory for other environments. If you installed tower skills,
inspect and remove their links too: `mct` and `rct`, or `mct-claude` and `rct-claude`.
Preserve unrelated files. Removing skill links leaves repositories and PRs intact.
After every Shaka link in that skills directory is removed and no install is
running, remove its `.shaka-install.lock` file too.
Managed copies remain available for rollback; remove one only after no host link
or active task uses it.

### Extra entries and retained copies

There is no automatic cleanup or expiry. Upgrades switch the link in the supplied
skills directory and retain earlier packages for rollback. Retained packages do
not create menu entries by themselves; another discoverable skill link does.
PR trial preparations also retain their packages, without adding normal host links.

When the user wants to remove a duplicate entry, inspect `shaka` links in every
skills directory their host reads. For example, Codex can discover both
`~/.agents/skills/shaka` and `~/.codex/skills/shaka`. Unlink the unwanted entry using
the removal procedure above, preserving the desired entry. Start a new chat or
restart the host if its skill list still shows the removed link.

Delete a retained package only after all chats pinned to its absolute skill or
helper path have finished and no host link points to it. Check other coding hosts
as well as the current one. Keep copies needed for rollback. Shaka does not track
active chats across hosts, so an unlinked package alone is not proof it is unused.
Old packages keep their original menu labels until replaced by a new installation.

## Development environment details

Use the following sections for terminal launchers, usage hooks, and environment
limitations. Basic installation uses the directories above.

## Codex

In the app, open a task in your repository and invoke `$shaka`.

For a terminal session, the optional launcher creates a separate session directory
and gives the Codex sandbox write access to that directory and your checkout:

```bash
"$HOME/agent-tools/shaka/bin/install" --managed --skills-dir "$HOME/agent-tools/shaka-pilot/skills"
"$HOME/agent-tools/shaka-pilot/skills/shaka/scripts/shaka" work \
  --repo /path/to/repository "Fix the failing search test. Use Ask."
```

Replace the path and task. Native trust and command-approval prompts still apply.
The launcher refuses paths that overlap the trusted installation. Choose a
`TMPDIR` outside the checkout if your current one is inside it.

The optional `mct` and `rct` skills need the **Codex app's** task and project tools.
Select them independently with `--with-mct` and `--with-rct`; terminal-only installations use the [control-tower role prompts](control-towers.md#role-prompts).

## Claude Code

Install into `~/.claude/skills`, then start `claude` in your repository and invoke
`/shaka`. Shaka has no Claude Code launcher. Your existing permission mode applies;
keep its trusted source outside the checkout and any writable `--add-dir` path.

The desktop app can also use `mct-claude` and `rct-claude`. Install them with
`--with-claude-towers` and follow [control-tower setup](control-towers.md).
Those skills require desktop session tools and cannot run in the terminal CLI.

## Cursor

Install into `~/.cursor/skills` and start a new Agent chat to confirm discovery.
The recorded trial did not discover the skill through `~/.agents/skills`.

To save token usage, add this entry to the `stop` array in `~/.cursor/hooks.json`,
preserving existing hooks:

```json
{
  "command": "skills/shaka/scripts/cursor-usage-hook"
}
```

On Windows, use the launcher instead. Cursor cannot run the extensionless script, and the hook
process may not have `ruby` on its PATH. The launcher finds `ruby.exe` from the user or machine PATH.

```json
{
  "command": "skills/shaka/scripts/cursor-usage-hook.cmd"
}
```

Start a new chat after changing hooks. User-level hooks run from `~/.cursor`, so
this relative path reaches the installed skill. The hook saves aggregate usage
fields; it does not save prompt text. When this conversation already published a
description, the hook then fills that description's Cursor usage row.
[Usage reporting](usage-reporting.md#what-the-cursor-reader-includes)
explains what is counted.

## OpenCode

Use `~/.config/opencode/skills` to avoid overlapping compatibility installations.
Keep the skill outside the repository's `.opencode/skills`, where candidate code
could replace it.

You can also start the interactive TUI through the installed helper:

```bash
"$HOME/.config/opencode/skills/shaka/scripts/shaka" work \
  --host opencode --repo /path/to/repository "Fix the failing search test. Use Ask."
```

The launcher disables project-local OpenCode configuration, plugins, and
instructions. Trusted global configuration still loads, and your existing
permissions apply. Account and model settings are unchanged.

For usage, provide the session ID from `opencode session list`:

```text
shaka usage --host opencode --session ses_ID --commit FULL_COMMIT_SHA --contribution implementation
```

## Pi

Pi uses the shared skill and its existing tool permissions. There is no separate
Pi launcher or tower skill. Its usage reader needs a persistent v3 session with
matching `PI_SESSION_FILE` and `PI_SESSION_ID` values. Missing or unsupported
records produce `UNKNOWN`.

For actual session renaming, manually add the installed skill's absolute
`extensions/pi-session-name.js` path to the `extensions` array in your personal Pi
settings file (`~/.pi/agent/settings.json`, or under `PI_CODING_AGENT_DIR`). Preserve
existing settings and extension entries. For example:

```json
{
  "extensions": ["/absolute/trusted/skills/shaka/extensions/pi-session-name.js"]
}
```

Keep this path outside candidate checkouts. Run `/reload` in Pi after changing settings.
The extension exposes `shaka_session_name`; omit `name` to read the current title or
supply it to request a rename. It changes session metadata through Pi's API, not the
terminal window title. Follow [chat naming](launchers-and-sessions.md#name-the-chat).
Without the extension, the workflow prints a suggested title only. Shaka's installer
does not register the extension automatically. No additional npm packages are needed.

## Operating details

Agents should read [launchers and agent sessions](launchers-and-sessions.md) when launching
Codex/OpenCode or enumerating Claude Code tower sessions. [Usage reporting](usage-reporting.md)
covers session selection, token categories, and attribution limits for each host.
