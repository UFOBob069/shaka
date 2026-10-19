# 0002: Install locations and no backward compatibility

Status: accepted on 2026-10-18; not yet implemented. Each decision ships
through its sub-issue of #683, and until then the installer behaves as before.
Date: 2026-10-18. Tracks [issue #683](https://github.com/shakacode/shaka/issues/683).

## Context

A maintainer ran `git pull` inside the registered Shaka source checkout. Every
install action then failed with `Installation revision changed outside the update
procedure`, and the only way out was reading the source.
[PR #674](https://github.com/shakacode/shaka/pull/674) fixed that case.
The same machine showed three more problems:

- The source checkout was also the development repository, with many linked
  worktrees and local branches.
- A second registered checkout at `~/.agents/shaka` was mistaken for configuration,
  because each project keeps its settings in `.agents/shaka/`.
- The installer carried old formats (managed copies, Codex aliases, the old
  `.agents/agent-workflow.yml` settings layout, and migrators for them). Every new
  safeguard had to handle those formats too.

Issue #683 lists every reachable install state and the step that fixes each one.

## Decisions

1. **New installs default to `~/.local/share/shaka/source`.** `.agents/shaka` is the
   settings location only. The installer refuses `~/.agents/shaka` and any directory
   under `~/.agents/` as an install directory.
2. **Worktrees are refused.** The installer refuses a source checkout that is
   itself a linked worktree, because a worktree is deleted when its branch merges and
   every host link would break. It also refuses a checkout that hosts linked
   worktrees or local branches other than the registered branch, and
   `install --verify` warns when they appear later. Develop in a separate clone.

   The refusals in decisions 1 and 2 stay fixed, with no override. A worktree
   checkout loses every link when its branch merges. Developing in the source
   checkout produced the drift in the Context, which left every install action
   failing. An install under `~/.agents/` has no supported path once decision 5
   lands. Before 1.0 there is no migration out of any of these states, so the
   `AGENTS.md` rule on fixed behavior allows the refusals as keeping an install
   out of a state that breaks it.
3. **Automatic updates are opt-in.** Updating the single source checkout can change
   files that open chats are reading. Scheduled updates stay opt-in until each revision
   gets its own folder.
4. **Records.** This ADR records the decisions. Issue #683 tracks the work in
   public, with one sub-issue per step.
5. **No backward compatibility before 1.0.** Old install locations and formats are
   refused with one reinstall command, not migrated. Legacy code is removed in
   [#692](https://github.com/shakacode/shaka/issues/692) after every repository the
   maintainer uses is converted off the old settings layout in
   [#691](https://github.com/shakacode/shaka/issues/691). PR trials stay.

## Consequences

- Refusals replace migrations: a user on an old location or format gets a message
  naming the state and the one command that reinstalls or converts.
- Repositories still on `.agents/agent-workflow.yml` stop working once #692 lands,
  so #691 converts them first and the release notes say so.
- The install code and its tests shrink. Status, repair, and the scenario harness
  only need to cover current formats.
- Issue #689 validates every install state end to end before #683 closes.
