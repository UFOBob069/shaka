# Control towers

![A central coordination tower connects three smaller towers, each with its own platform and work units.](img/coordinated-towers.webp)

Control towers are optional tools for tracking work across repositories. Try Shaka
on a few tasks first.

A **Repository Control Tower (RCT)** follows one repository's priorities and tasks.
A **Master Control Tower (MCT)** coordinates RCTs and dependencies—for example, a
library fix needed before an application upgrade.

![A Master Control Tower coordinates Repository Control Towers. Each repository tower follows its delivery tasks, and each task has one owner.](img/control-towers.svg)

Each delivery still has one owner. The [architecture guide](architecture.md)
explains where its records belong.

For Codex, ask your agent:

```text
Install Shaka's control towers for Codex.
```

1. If you already have a master chat, continue there. Otherwise, choose one
   chat to coordinate your projects and run `$mct` there.
2. Open a chat in each repository's Codex project and run `$rct` to connect it
   to the master.

In Claude Code, use `/mct-claude` and `/rct-claude` instead.

After the master acknowledges the repository tower, ask the tower what needs
attention. You choose which task starts; setup starts no backlog work or recurring
scans.

Keep each tower set in one environment: Claude and Codex cannot read each other's
sessions. Ask the owning tower to explain its setup, ownership, or handoff before
moving work between environments.
