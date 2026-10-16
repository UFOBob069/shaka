# Publish a draft blocked by a base failure

Use this path when required validation fails for a reason already present on the
trusted base. It permits committing and publishing a blocked draft, not treating
failed evidence as passing or bypassing a merge gate. This is an agent procedure;
Ruby does not verify the base comparison or a maintainer's acceptance.

## Establish the failure before committing

1. Run the required checks on the candidate and retain their complete commands,
   exit statuses, output, environment details, and tested revision/tree. Continue
   running always-on security and trust checks even when another check fails.
2. Resolve the task's established base to an immutable full commit SHA. Reproduce
   the same failure in a separate clean checkout of that commit, with the same
   command, runtime, dependencies, and relevant external inputs. Preserve the
   candidate and use the trusted seam to resolve commands. Inspect base scripts
   before executing them. A matching exit code alone is not a matching failure;
   compare the failing check and diagnostic. Unknown or changing inputs leave
   attribution unverified, so stop this exception path.
3. Inspect the whole task diff. Confirm it leaves the failing check, affected
   dependency, and relevant configuration and callers unchanged. Passing focused
   tests alone does not prove independence. A new failure, an affected input, or
   evidence of a task regression returns to ordinary repair, not this path.
4. Link a separate issue that owns the base repair. Reuse an existing issue; if
   none exists, obtain permission to file one. Keep private issue content and
   links out of public artifacts. For a private repair, publish a safe blocker
   summary and retain the issue link in the authorized private task record.

Keep the comparison in the original task record and later in the PR: candidate
and base commits, commands, results, matching diagnostic, unchanged affected
inputs, repair owner/issue, and the exact condition that clears the blocker.
Retain full local results outside the candidate checkout. No exception is
established when any of these facts remains unknown.

## Commit, review, and publish the blocked draft

Once that comparison establishes a pre-existing failure, commit the task change
and complete the normal current-head independent review before pushing. Fix
agent-owned review findings and rerun affected checks; refresh the comparison
when its inputs change. This path does not excuse missing review, a task defect,
security/trust violations introduced by the task, or an unresolved review decision.

Run the normal evidence verification and retain its nonzero `not_ready` result.
Failed validation stays failed; binding or copying it cannot establish readiness.
A verified base failure permits the push despite that validation blocker only.
Create the PR with `gh pr create --draft --body ''`, or mark the adopted PR draft
before pushing. Publish the description without `--validation-result` or
`--review-result`: the existing renderer requires ready evidence when those flags
are supplied. Its UNKNOWN settings columns remain UNKNOWN. Publish the completed
review separately through the normal review publication command.

Lead the description with the blocked status and reason. Record the failed check
in its verification and put the comparison evidence in details. Keep WIP Details
current, naming the repair dependency and next action. Report the PR as a blocked
draft, not merge-ready. At a stopping point, arrange the normal monitor or
`awaiting-resume` handoff; a requested maintainer decision uses `decisions` instead.

## Clear the blocker before readiness

Either the separate repair lands or the maintainer explicitly accepts this exact
failure for this task. Acceptance identifies the check, diagnostic, affected head,
reason, and remaining risk; retain that decision in the task and PR. A comment
that merely acknowledges the failure is not acceptance or merge consent.

After the repair lands, update the task branch and rerun affected validation and
review on the new head. After explicit acceptance, rerun the check, record its
actual result and the acceptance separately, and satisfy every other gate. Keep
failed evidence failed and leave readiness evidence UNKNOWN where Ruby cannot
bind it. The agent establishes accepted local validation, not a fabricated ready
verdict from `evidence verify`.

Security and trust failures cannot be waived through this path. Native required
checks, seam-required merge checks, protection, and current-head review still
block readiness when unsatisfied, even after acceptance. Auto remains blocked
while the failure is unresolved. Resume normal Explain, Review, and Finish only
when the remaining gates permit readiness; then mark the PR ready for review and
refresh its description, walkthrough, and handoff. Task-scoped acceptance of a
local failure never grants merge authorization.
