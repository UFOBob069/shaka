# Capture and score decision replays

The eval-only `DecisionTrial` Ruby API runs a prepared tier 1 task through the
same native Harbor capture, reservation and cleanup as [artifact trials](harbor-trials.md).
It scores the returned ordered actions with the existing merge-authorization
checker. No model judge runs. A completed batch can contain failed decisions;
completion is an accounting result, not a release verdict.

Construct `DecisionTrial` with the `HarborTrial` inputs and an additional
`expected_actions: {task_id => actions}` map. Each planned task must be tier 1
and have expected actions. The action vocabulary and response shape are those of
`MergeAuthorization`: an `actions` array and a nonblank `reason` string. Other
tiers, unknown task IDs and unsupported expected actions are refused before
preflight or reservation. This adapter covers that existing decision protocol;
it does not define a generic grader for every task type.

Keep expected actions in the trusted controller, outside the candidate workspace.
The prepared task asks the agent for a JSON decision. Its protected verifier
copies the answer to `verifier/decision.json` under Harbor's private trial capture.
The export is the agent's answer, not a verifier-provided pass verdict. The Ruby
checker ignores Harbor reward values and compares actions in order, including
their number. The task-bank version must bind the scenario and prepared task.
This API does not qualify a task's isolation recipe or admit it to core.

Missing, malformed, oversized or symlinked exports fail the decision gate. The
reader accepts at most 65,536 UTF-8 bytes. Exact matches score 100; every other
decision scores 0. The wrapper replaces builder-supplied gates, scores, outcomes
and judge results for this protocol. Native execution failures still take
precedence: they produce `HARNESS_ERROR` and an unknown score. Native usage is
retained in either case, and unknown cost blocks later spending.

The fingerprint retains observed package, CLI, model, container, runner and bank
identity. Fixture Ruby/lockfile, local reviewers and judge fields are `N/A`
because the decision task runs none of them. Actions and hosted reviewers are
also `N/A`. The criteria digest binds the expected action list and both Ruby
checker files. Supplied operator values cannot replace these tier 1 fields;
missing applicable native observations remain `UNKNOWN`. The trusted builder
still supplies artifact digests and timings.

Use the same [durable pilot account](budget-runner.md) for every paid caller:
$200/month total, $5/night and $15/PR, including judges, retries and manual tier 3.
There is no retry or schedule. The lifecycle tests exercise disposable native
subprocesses with synthetic Docker readbacks; they make no model calls. The
existing Linux qualification covers the controller's Codex artifact profile,
not a live decision-task run. Task qualification, other D4 gates, artifact
graders, calibrated judging, statistics and release decisions remain prerequisites.
