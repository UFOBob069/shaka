# Conditional workflow loading investigation

Recommendation: move procedures used by a subset of tasks behind explicit
applicability rules. Keep trust, authority, completion criteria, and failure
dispositions visible in the workflow. Reuse its existing reference links;
a loader, host hook, or new skill is unnecessary for this change.

This is a public technical investigation, not evidence of improved delivery
speed or lower model cost. Task frequency and real-use effects remain unknown.

## First bounded change

Extract UI verification and performance comparison details into separate agent
references. The workflow still states when to read each reference, requires UI
publication before Finish, and retains its completion criteria. Neither the
entry point nor the renderer changes. Independent PRs can evaluate later
extractions; this change has no prerequisite PR.

| Task | Additional procedure loaded | Safeguards retained |
| --- | --- | --- |
| CLI-only fix with no page-speed effect | Neither new reference | Validation, independent review, publication, checkpoint, and merge authority |
| Visible UI change | UI verification; its existing annotation reference | Manual use at the pushed head, desktop/mobile captures, privacy inspection, verified upload, preview pass or recorded gap, and refresh after runtime changes |
| Page-speed, loading, caching, or streaming change | Performance verification | Base comparison, changed-path coverage, sample/revision reporting, result freshness, repair or maintainer acceptance of adverse results |
| UI and speed change | Both | Both sets of evidence; captures still complement tests |

The UI upload failure markers remain in the workflow, along with the rule that
captures do not replace tests. The enforcement manifest keeps its existing
entries and quotes. Benchmark failure dispositions remain in the conditional
procedure and the Verify completion criterion continues to require their result.
These are agent instructions; Ruby does not classify a task or prove it loaded
a reference. Existing checks validate workflow shape, links, and enforcement
quotes, not execution of the instructions.

## Loading cost

Against Shaka `0408d279a64255e94a6a604ec4b945a109615fae`,
`bin/report-instruction-growth` measures the rendered workflow from 11,032 to
10,610 words: 422 fewer words (3.8%) and 2,573 fewer UTF-8 bytes.
The entry point remains 254 words and project guidance remains 1,709 words.
The new UI reference has 309 words; performance has 288. The reference index
adds 14 words. Across these instruction surfaces, total text grows by 189 words.

An ordinary task avoids both references. A UI-only task adds the UI reference;
a speed-only task adds performance. A task needing both loads more text than
before. The existing annotation reference already applied to UI changes.
These are static loading paths, not measured agent traces or token counts.
The small reduction justifies a bounded trial, not a claim of major savings.

## Other candidates

| Procedure | Condition worth routing on | What stays visible; work needed before extraction |
| --- | --- | --- |
| Private/team first setup | Trusted seam is absent and setup mode is established | Stop on invalid policy; retain private-use authority limits and first-setup PR handling; compare every recovery path |
| Reviewer execution failures | Selected reviewer returns a failure | Keep trusted selection, qualifying unavailability, account refusal, and no-unreviewed-publication boundaries; reconcile existing local-review references |
| Issue offers | Root owner finds a verified gap outside the active request | Preserve separate query/text approvals and public-repository identity checks; relocating current classified quotes needs explicit audit treatment |
| PR-watch mechanics | A task waits for checks or trusted feedback | Keep the native-wake boundary and manual resume owner; preserve startup races, timeout/error handling, and exact-head refresh |
| Publication JSON/flag reference | Agent is about to publish | Already needed by most delivery tasks; moving it alone reduces the entry rendering but may save no task context |

Leave common validation, review requirements, Ask/Auto decisions, public-comment
trust, and substantive-concern blockers in the workflow. Later candidates need
their own safeguard comparison; this investigation does not authorize deleting
or weakening them.

## What Ponytail's structure contributes

Inspected upstream [tree at 84740e3](https://github.com/DietrichGebert/ponytail/tree/84740e3d344b69b4a133201fa519eb37a62a2b2a).
The installed local core is a trial adaptation; inspecting upstream did not
install its other skills or hooks.

- A compact [core skill](https://github.com/DietrichGebert/ponytail/blob/84740e3d344b69b4a133201fa519eb37a62a2b2a/skills/ponytail/SKILL.md)
  supplies coding principles. Separate skills provide review, audit, debt,
  help, and measured-gain reports. Its
  [review skill](https://github.com/DietrichGebert/ponytail/blob/84740e3d344b69b4a133201fa519eb37a62a2b2a/skills/ponytail-review/SKILL.md)
  has its own scope and reporting steps. Borrow the separation by job; Shaka
  can express these two conditional jobs with existing reference links.
- [Instruction loading](https://github.com/DietrichGebert/ponytail/blob/84740e3d344b69b4a133201fa519eb37a62a2b2a/hooks/ponytail-instructions.js)
  reads the canonical core, filters intensity-specific material, and carries
  fallback instructions. Review mode returns a short pointer to its separate
  skill. This is runtime behavior to maintain, not just a small Markdown file.
- [Rule-copy checking](https://github.com/DietrichGebert/ponytail/blob/84740e3d344b69b4a133201fa519eb37a62a2b2a/scripts/check-rule-copies.js)
  checks compact host copies and selected invariants between the core and
  compact rules. Shaka already has a validated renderer, link tests, and an
  enforcement manifest. Reuse those rather than introducing copied host rules.
- The tree also contains host adapters, lifecycle hooks, mode state, a regex
  codebase map, tests, and benchmarks. Those support Ponytail's integrations;
  this extraction demonstrates no need to import them. Upstream tests and
  benchmark claims were inspected selectively, not executed or reproduced.

## Predecessor check

Inspected `shakacode/agent-workflows` at
[`d85ecea`](https://github.com/shakacode/agent-workflows/tree/d85eceaecac1b8c4d55a7889a806bd89a612a493),
including its [worker procedure](https://github.com/shakacode/agent-workflows/blob/d85eceaecac1b8c4d55a7889a806bd89a612a493/workflows/pr-batch-worker-execution.md),
[verification entry](https://github.com/shakacode/agent-workflows/blob/d85eceaecac1b8c4d55a7889a806bd89a612a493/skills/verify/SKILL.md),
and [drift tests](https://github.com/shakacode/agent-workflows/blob/d85eceaecac1b8c4d55a7889a806bd89a612a493/bin/check-agent-workflow-drift-test.rb).
It uses explicit loading conditions and verification references, but its batch
coordination contracts and drift machinery solve broader problems. Reuse the
conditional-reference pattern already present in Shaka. No predecessor code or
workflow contracts enter this change; its tests were inspected, not run.
