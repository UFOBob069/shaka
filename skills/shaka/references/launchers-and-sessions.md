# Launchers and agent sessions

Use this reference for launcher boundaries, chat naming, and Claude Code tower discovery.
Installation belongs in [the installation reference](installation.md); dated trial results
belong in the [validation record](https://github.com/shakacode/shaka/blob/main/internal/coding-environment-trials.md).

## Codex launcher boundary

`shaka work` creates a private temporary session outside the consumer checkout.
It names the trusted skill by absolute path and directs repository commands to
the checkout. It adds no discovery link to the writable session.

The launcher rejects canonical and lexical overlaps between writable paths and
the trusted source, installed command, or link parents. The sandbox overrides
extra writable roots and excludes ambient temporary directories. Shell `TMPDIR`
and zsh `TMPPREFIX` point inside the session's temporary directory. Session
scratch remains after exit; no background process remains.

Establish these permissions even when existing coding-agent configuration grants broader
access. A trusted installation in a writable temporary directory breaks the
boundary. Native approval prompts still apply; do not approve an escape merely
to make a check pass. This boundary does not establish dependency trust or screen
text for publication.

## OpenCode launcher boundary

`shaka work --host opencode` starts the TUI in the repository and refuses overlap
with the trusted workflow. OpenCode stores sessions outside the checkout, so the
launcher creates no separate session directory.

The launcher sets `OPENCODE_DISABLE_PROJECT_CONFIG` to prevent loading candidate
`.opencode` plugins, `opencode.json`, and instructions. Trusted global configuration
still loads. Account, model, and permission settings remain the coding agent's responsibility.

## Name the chat

Workflow titles look like `SHAKA #131 · Drop skill-path stop`, or
`SHAKA PR #257 · Chat-name fallback` once a PR exists. Omit `#ISSUE` for work without an
issue. Hosts differ in how the agent renames its own chat:

| Host | How the agent renames its chat |
| --- | --- |
| Claude Code in the Claude desktop app | `set_session_title` with `session_id` `self`. The tool is deferred, so load it through tool search before deciding the host has none. Read the title back with `get_session`. |
| Codex desktop | The native task rename tool, as the RCT skill uses it. |
| Claude Code terminal CLI | No agent tool. Use the `Chat name:` line. |
| Pi | With the [optional naming extension](installation.md#pi), call `shaka_session_name` with `name` to rename, then without arguments to read back the actual title. Without it, use the `Chat name:` line. |
| Other hosts | Use a rename tool only when the host offers one. Otherwise, use the `Chat name:` line. |

The app asks the user to approve a rename when the user chose the current title. Treat a
declined rename as a user-chosen title and do not retry it. Pi's extension confirms before
replacing a title it did not set, preserves declined titles, and updates its own titles without
another confirmation. A `preserved` result leaves the actual name unchanged; use that name in WIP Details.

For title confirmation and WIP refresh after a rename, follow the
[WIP Details procedure](delivery.md#recover-an-unfinished-pr).

## Claude Code tower messages

Desktop towers use `get_session`, `list_sessions`, `list_events`,
`set_session_title`, `set_pinned`, and `send_message`. The terminal CLI lacks
these tools. Use title suffixes for discovery and each tower's own recorded
setup for ownership. Sidebar groups are unused because `move_sessions`
unpins a pinned session.

`delivered` means the target session's turn started on the message and `queued`
means it waits behind current work; neither is the other session's answer.
`undelivered` means the target had not started within the host's wait; the message
can still land later without the target taking a turn on it.

Record the setup in the tower's own transcript before sending; the master reads it
with `list_events` on its next turn. There is no bounded wait for another session:
report the result and end the turn. Do not poll, re-send, or start a monitor.

## Read the session listing completely

`list_sessions` returns a recent page and excludes the calling session. Increase
the limit until the listing is exhausted; otherwise an older tower can be missed
and a duplicate created. Apply this to every setup and ownership refresh.

If the result is too large, read the file path returned by the coding agent. Retrying with
a smaller limit loses sessions. A September 18 trial needed 413 sessions and
produced roughly 210 KB, so this is a normal case to handle.

Add the caller separately. `get_session` supplies its title, but `list_events`
refuses its own transcript. The caller's registration must therefore come from
its current conversation, as the tower skill specifies. Missing history leaves
that registration unverified.

`search_session_transcripts` searches message contents, not titles. Discover
candidates with `list_sessions`, then confirm their recorded role with
`list_events`.
