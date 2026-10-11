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

Once per chat, run the saved helper's `update-check`; relay its guidance only for `available`. Continue with the saved helper; updating is a separate user action.

With no task or with `doctor` alone, follow the [guided start](references/guided-start.md)
and stop after its welcome or diagnostic. For a task, continue below.

Run the trusted helper's `workflow` command now and follow the complete validated procedure it
prints. The packaged YAML owns the workflow text; Ruby validates its schema and phase order
before rendering it. If loading or validation fails, stop and report the error instead of
reconstructing the workflow from memory.
