# Evaluation experiments

[Test locally before pushing or opening a PR](../contributing/evaluating-changes.md#test-before-pushing-or-opening-a-pr)
when possible. Keep early evidence locally and summarize it when publishing.

Start by [choosing an evaluation method](../contributing/evaluating-changes.md#choose-an-evaluation-method):
a real-work trial, a focused comparison, or a full isolated evaluation. Use the
[real-work trial guide](../docs/trying-pr-versions.md) for the workflow introduced
by [PR #367](https://github.com/shakacode/shaka/pull/367); post authorized feedback
on the candidate PR instead of duplicating each trial here.

This index links comparison reports and harness attempts. It prevents a harness failure from being mistaken for a
successful skill evaluation or repeated without a changed hypothesis.
Prepared tier 1 tasks can use the [native decision replay API](decision-replays.md)
for accounting, fingerprint capture and exact ordered-action scoring.

| Experiment | Evidence | Outcome |
| --- | --- | --- |
| Merged Harbor controller, #621 | [Linux qualification, native cost and cleanup](reports/harbor-launch-qualification.md) | One Codex trial passed through the budgeted API at $0.2421 cache-neutral API-equivalent cost after a pre-generation authentication failure was reconciled at zero. No pending reservation or owned resources remain. Execution qualification only; the fingerprint is provisional. |
| Harbor execution-layer spike, ADR 0001 D15 | [Pins, trials, repairs, cost, and limits](reports/harbor-spike.md) | Twelve trials completed on Linux. Codex baseline 0/3, repaired 3/3; Claude 3/3 on both. Both hosts also passed with an upload adapter and ICMP restriction. Total observed inference $6.31 API-equivalent including repairs and confirmations. Recommend Harbor for tier 2; adoption remains the maintainer's decision. |
| Early caller verification, #421 | [Fixture, traces, outputs and limits](reports/early-verification.md) | Both arms reproduced before editing. Candidate exercised chunk boundaries and fixed an empty-chunk failure; its output passed all 1,785 independent assertions, baseline failed. One pair per wording and typo controls; broader effectiveness remains unknown. |
| Ask authorization decision replay, #399 | [Fixture, pins, results and limits](reports/ask-merge-authorization.md) | Baseline chose unauthorized merge or enqueue in all five Ask cases, including changed seam and missing Intake state. Repaired workflow handed off all five with no simulated merge effects; explicit approval and Auto remained positive. Focused model decision evidence; no real GitHub mutation. |
| Slice 0 main/Ask r4 | [#206](https://github.com/shakacode/shaka/issues/206); repository deleted before the retention decision | Harness failure. The repaired PR passed checks, but the final image's GitHub CLI could not execute the trusted required-check query. No COMMENT walkthrough or Ask marker. |
| Slice 0 main/Ask r5 | [retained repository](https://github.com/shaka-eval-repos/shaka-slice0-ask-feasibility-206-r5), [PR #1](https://github.com/shaka-eval-repos/shaka-slice0-ask-feasibility-206-r5/pull/1) at `7820fab178704b7a9cea88d480b7542bc753e40d` | Harness failure. The intended initial assertion failed locally and in hosted CI; the repair passed both, but restored the base exactly. With zero changed files, the trusted walkthrough could not publish. PR remains open and unmerged; no Ask marker. |
| Writing-style loader [PR #250](https://github.com/shakacode/shaka/pull/250), offline smoke | Historical baseline `ceb9989`, candidate `e387b5d`; [guide](../contributing/evaluating-changes.md#first-value-case-pr-250) | Baseline omitted `writing_style`; candidate returned a 903-byte trusted guide. Mechanism evidence only, not model behavior or value over a pointer. |
| PR #250 / PR #326 task replay, first pair | [Full pins, tests, usage and cleanup](https://github.com/shakacode/shaka/pull/250#issuecomment-5906768008); [baseline PR](https://github.com/shaka-eval-repos/shaka-pr250-pr326-replay-a/pull/1) at `3730b62`; [candidate PR](https://github.com/shaka-eval-repos/shaka-pr250-pr326-replay-b/pull/1) at `5ebc6a2` | Baseline helper `682527f`, candidate `9e25abe`; same target/style pointer and gpt-6.1-sol/medium, two fixed turns, 30 minutes each. Baseline timed out before the final Ask marker despite green checks and walkthrough. Candidate finished Ask in 28m11s but failed an independent recording-receipt probe. Benefit inconclusive; PR #250 remains on hold. Temporary access and runtimes removed; repositories retained. |
| PR #250 / PR #326 task replay, one-hour pair | [Results, writing comparison and next work](reports/pr250-pr326-one-hour.md); [execution evidence](https://github.com/shakacode/shaka/pull/250#issuecomment-5911241095) | Both delivered Ask and passed independent probes. Baseline 41m03s, candidate 46m22s. Writing differences are mixed; incremental value is inconclusive. Process reaping, portable trust setup and one grader assumption needed attention. Repos retained; temporary access removed. |
| Dependency-aware spec delivery, #457 | [Specification, fixture, static comparison and limits](reports/dependency-aware-spec-delivery.md) | Not run. Adopting `implement-spec` as shipped is rejected from its instructions: one combined branch, a merger subagent, review run by the same orchestrator, and tickets closed at the end of a run contradict the trusted workflow. The smaller dependency-aware handoff is inconclusive; every run measurement is UNKNOWN pending authorization. |
| Correction replay, #468 | [URI results, PR #463 timeline, decision comparison and limits](reports/correction-replay-463.md) | The #463 regression fails on URI 1.0.3 and passes on 1.1.1 before the fix. Baseline and candidate both kept every required rerun and handed off under Ask; the candidate reused the walkthrough. Focused model decision evidence, one run per cell; time saved is UNKNOWN. |

New full isolated evaluations use the [simple default](../contributing/evaluating-changes.md#simple-default-one-matched-pair):
one matched pair, one hour per arm including CI, separate time and cost limits.
The first pair above keeps its original 30-minute limit; a longer follow-up gets
its own record and does not turn that timeout into a historical success.
For an unclear result, [identify the missing evidence](../contributing/evaluating-changes.md#when-a-result-is-inconclusive)
before scheduling another run. The historical PR #250 pairs remain inconclusive;
a later trial is new evidence, not a correction to their outcomes.

Retain evaluation repositories and PRs for history, keeping private measured cells
inaccessible to later agents. Remove temporary access after each run. Before a
new experiment, compare its hypothesis, fixture, baseline and candidate commits,
model/effort, prompt, and success gates with
this index. Public solved repos are not hidden test cells.
