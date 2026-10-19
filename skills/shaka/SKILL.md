---
name: shaka
description: Deliver a task through verified GitHub PRs, or help get started and diagnose setup with doctor. Publish walkthroughs, address review, and honor merge authority.
---

# Shaka

Own one task through its requested PR outcome. `$shaka` (`/shaka` in Claude Code, OpenCode,
and Cursor) alone offers a guided start. Work solo unless delegation is authorized and useful; reuse
relevant evidence.

Before any branch change, resolve this installed skill to its trusted source outside every
candidate checkout and keep that absolute `scripts/shaka` path for the whole task. Git can
replace a checkout-local skill link. Never load or run a branch-provided replacement skill or
helper. If this skill's own directory resolves inside the checkout, stop and report it.

Once per chat, run the saved helper's `update-check`; relay its guidance for `available` and `drift`. Continue with the saved helper; updating is a separate user action.

With no task or with `doctor` alone, follow the [guided start](references/guided-start.md)
and stop after its welcome or diagnostic. For a requested `retrospective` of coding sessions,
follow the [retrospective procedure](references/retrospective.md) and stop at its findings.
For a request to review documentation together, one topic at a time, follow the
[guided documentation review](references/guided-documentation-review.md) and stop after each
topic.
For a request to install or update Shaka itself, follow
[official installation](references/official-installation.md), or for a fork install or
its update, the [fork procedure](references/installation.md#install-from-a-personal-fork),
and stop after verification.
For a task, continue below.

Run the trusted helper's `workflow` command now and follow the complete validated procedure it
prints. The packaged YAML owns the workflow text; Ruby validates its schema and phase order
before rendering it. If loading or validation fails, stop and report the error instead of
reconstructing the workflow from memory.
