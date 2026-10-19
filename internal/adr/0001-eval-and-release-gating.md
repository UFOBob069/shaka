# 0001: Eval and release gating

Status: proposed; Harbor execution-layer choice accepted on 2026-10-16.
Date: 2026-10-07, revised 2026-10-12 to remove company-specific
planning and clarify evaluation rules. Tracks [issue #206](https://github.com/shakacode/shaka/issues/206).

Shaka changes agent behavior through prose in skill files and through deterministic
Ruby. Tests prove the Ruby. Beyond anecdotes from real-work trials and two
inconclusive matched pairs, nothing today measures whether a prose change helps,
and nothing between releases proves that the merged changes still work together.
This record decides one eval system that serves three uses: judging a single PR,
gating a release, and letting users compare their own prompts.
The same run record, the same single-axis diff, and the same side-by-side diff card
serve all three. Cheap models with light thinking plus strong deterministic Ruby are
the thesis under test, so the cheap tier is the gate and the strong tier is the audit.

Throughout, **Shipped** marks behavior that exists in the repository today,
**Decision** marks what this record settles, **Proposed** marks design that still
needs code, and **Agent instruction** marks a rule that only the agent enforces.
Nothing in this record is enforced until the named Ruby exists.

## Context

### What exists today

Shipped, under `eval/` and documented in the
[experiment index](https://github.com/shakacode/shaka/blob/main/eval/README.md):

- A [local evaluation proposal](https://github.com/shakacode/shaka/blob/main/internal/local-evaluation-proposal.md)
  approved for a bounded Slice 0, with a container isolation recipe, a two-message
  startup script, terminal states (`PASS`, `NEEDS_APPROVAL`, `FAIL`,
  `BLOCKED_EVIDENCE`, `NEEDS_INPUT`, `LIMIT_REACHED`, `HARNESS_ERROR`), and a
  one-hour-per-arm matched-pair default recorded in the
  [contributor guide](https://github.com/shakacode/shaka/blob/main/contributing/evaluating-changes.md).
- A probe container builder that pins the base image by digest, starts with
  `--init`, drops capabilities, mounts the fixture and the trusted skill read-only,
  and refuses a trusted helper that lives inside the candidate checkout. It builds
  the Docker command line; it does not run an agent.
- Two public-safe fixture trees: small Ruby and Minitest consumer repositories with
  a seam, pinned Actions, and a four-field `fixture.yml` (`version`, `purpose`,
  `public_safe`, `reusable_for_measured_cases`). The file is a label, not a task schema.
- One focused decision eval: eight merge-authorization scenarios rendered into a
  prompt with the workflow, answered by a model as JSON, and graded by exact match
  of the action list. The repaired workflow scored 8 of 8 against a baseline of 3 of 8.
  This is the cheapest working shape in the repository and the pattern this record
  generalizes.
- Three experiment reports, one of them a manual instruction replay with no model
  run. The two full delivery pairs were inconclusive on value and taught harness
  lessons: start containers with `--init` and verify process reaping before adding
  credentials, prepare the fixture trust file for the destination owner, correct a
  wrong grader assumption and re-apply it to both arms, and treat a repair that
  restores the base byte for byte as a harness error.
- A versioned run-record schema and offline Ruby structure check. Record capture
  and execution are unbuilt; the proposal's `plan`, `selftest`, and `run` commands
  do not exist.

Shipped in the product runtime, and reusable by an eval:

- The real-work trial workflow from [PR #367](https://github.com/shakacode/shaka/pull/367):
  `shaka trial prepare` pins a PR revision for a fresh chat and `shaka trial report`
  posts keep, revise, or drop feedback on the candidate PR. See
  [Try a Shaka PR on real work](../../docs/trying-pr-versions.md). It yields examples and
  friction, not a controlled comparison, and it is the path
  `internal/requirements.md` names for real-use acceptance.
- Deterministic publication validators: `shaka description`, `shaka walkthrough`,
  `shaka reply`, and `shaka squash-message` verify required keys and sections, the
  managed region markers, head binding, changed-file links, prose length limits,
  table shape, and footer markers. `shaka merge` and `shaka handoff` verify the
  evidence a PR needs before merge or handoff. `shaka enforcement` verifies that
  every must, never, do not, and only-when rule in the workflow is classified.
  `shaka seam check --ref` validates the repository contract from a trusted commit.
- Identity and usage capture: the workflow version renders the installed commit
  with a modified flag; the usage command parses native Codex, Claude Code, Cursor,
  OpenCode, and Pi records into provider, configured model, routed model, effort,
  and token counts by category, priced from a versioned rate card at
  `skills/shaka/config/model-rates.yml`; a configuration fingerprint digests the
  effective settings, the trusted config, the installation identity, and command bytes.

For comparisons outside the core benchmark, this record proposes a blind human
verdict with a reason, followed by revealed settings and metrics. This is a general
evaluation interface, not a commitment about another product's features or rollout.

### Constraints this record honors

- `shakacode/shaka` is public, and `docs/` publishes to the public docs site.
  Reference solutions, hidden tests, rubrics, judge anchor sets, raw transcripts,
  per-run records, and machine identities are not public material. They live in a
  private repository or on local disk only. Aggregate API-equivalent cost and token
  totals are public, as every Shaka PR's usage block already is.
- An evaluation operator must set a fixed spending cap. Cost is a first-class
  requirement, not a report; the budget below is an illustrative rate-card estimate.
- Runtime needs no new gem. Eval code lives under `eval/` and stays out of the
  product runtime, per the proposal and `AGENTS.md`. Ruby standard library plus
  the GitHub CLI.
- The workflow is portable across hosts. The runner invokes whichever host CLI is
  installed; Codex was the first reference host and Claude Code is the second.
- Shaka CI never launches paid benchmarks. The proposed nightly batch runs on a
  maintainer-controlled host, scheduled outside CI.
- Private repositories on the GitHub Free plan have no GitHub-required checks.
  [PR #236](https://github.com/shakacode/shaka/pull/236) added seam-declared
  `merge.required_checks`, which only Shaka enforces; a GitHub merge click is not
  stopped. See [Before you start](../../docs/configure-repository.md#before-you-start).
- Merge rate: about 260 PRs merged in the three weeks after the only tag,
  `v0.1.0.pre.1`. "About 20 PRs per release" therefore means a release roughly
  every two days at the current pace, or a wider window. D9 states what the gate
  requires of the cadence.

### Decisions this record revisits

The September proposal said no evaluation on every main commit, no paid judge, and
human comparison only. This record replaces those with a bounded nightly head-of-main
run, a judge that runs only after the Ruby gate and only under the protocol in D5,
and blind human verdicts that remain the ground truth and calibrate that judge. The
proposal's isolation recipe, run-card defaults, terminal states, and fresh-repository
rule stay authoritative; this record points to them instead of restating them.
`internal/requirements.md` excludes release automation from the kernel; the gate
below is a maintainer tool outside the product runtime, and it automates a verdict,
not a release.

## The three uses

**Use 1, is this PR worth it.** A PR that changes skill or prompt behavior ships
with its own eval task or fixture. Before merge, the PR shows that its candidate
package hits the required format and sections, passes the Ruby validation checks,
beats the merge-base baseline on its own task, and does not hurt quality on the
cheap tier across the core benchmark, with the token cost delta printed beside the
quality delta. The task asked that a PR "beat its baseline on quality"; this record
reads that as improvement on the PR's own task plus non-inferiority on the core,
because a wording change rarely moves every core task and should not have to.

**Use 2, release gating.** Between releases, a nightly batch on a maintainer-controlled host
runs the core benchmark and every merged PR's task against the current head, paired
with the previous release package rerun the same night, and decides whether the
head is clean. Deterministic regressions surface the next morning. Judged quality
regressions of about ten points surface within one or two nights. Smaller effects
need the weekly strong-tier run or a confirmation rerun. The gate rule is in D9.

**Use 3, user-defined comparisons.** Users compare settings
for PR review, PR description, digest, and other prompt types, define what good
output means in their context, and read the result as the same diff card the
maintainer reads. These comparisons reuse the run record, the single-axis rule,
judge protocol, and diff renderer, with a criteria set, frozen inputs, and blind
human verdicts. Product-specific integration and commercial decisions are outside
this public record.

## Decisions

### D1. One run record for every trial

Decision. Every trial, in every use, produces one JSON run record with a stable
schema. A trial is one execution of one task version by one package under one
fingerprint. The record holds:

- `task`: id, task bank version, tier (D3), kind (regression or capability, D8).
- `fingerprint`: the full environment fingerprint (D2).
- `outcome`: the terminal state from the proposal's enum, plus `harness_error`
  detail when applicable.
- `gate`: each deterministic check with pass or fail and a short reason.
- `judge`: each judge call with model id, prompt hash, call kind (rubric on one
  artifact, or pairwise in AB or BA order), verdict, confidence or Unknown, and the
  facts Ruby supplied to it.
- `score`: the per-trial quality score defined in D8.
- `usage`: input, cached input, cache write, output, and reasoning tokens by model;
  cache-neutral dollars and billed dollars from the rate card version in the fingerprint.
- `timing`: wall clock for setup, agent turns, CI wait, verification, and judge.
- `artifacts`: digests and private paths of the PR description, walkthrough, review
  replies, diff, and transcript. Public records carry digests only.

Shipped: [the version 1 schema and offline Ruby check](../../eval/schemas/README.md)
validate record structure and task-bank identity consistency. Native fingerprint
assembly is described in D2. The [tier 1 decision adapter](../../eval/decision-replays.md)
captures and scores the existing ordered-action protocol; artifact grading remains proposed.

Proposed: `eval/bin/shaka-eval run` writes the record; `eval/lib/shaka/evaluation/`
holds the fingerprint reader and grader modules. The product
runtime's usage readers and workflow version are reused by calling the installed
`shaka usage --format json` and reading the provenance, not by importing product
modules into the eval.

### D2. A fingerprint on every run, and a diff only across matching fingerprints

Decision. Every run record captures this fingerprint. A field is one of three things:
a value, `N/A` when the field cannot apply to that tier, or `UNKNOWN` when it applies
and could not be read. `UNKNOWN` on a field that matters to the comparison marks the
run provisional; a provisional run can inform but cannot make a release clean (D9).

| Field | Source | Note |
| --- | --- | --- |
| Skill package digest | Installed tree plus every guide and helper it loads, plus the commit and modified flag | A root `SKILL.md` hash is insufficient, per the proposal |
| Workflow and enforcement hashes | `workflow.yml`, `enforcement.yml` | Separate from the package so prose-only changes are visible |
| Host CLI and version | `codex`, `claude`, `cursor`, `opencode`, `pi` | Never captured in evidence today; pinned in the image (D8) |
| Provider, configured model, routed model | Native usage records | Routed model is `UNKNOWN` on hosts that do not report it |
| Effort or thinking setting | Host flags and usage records | Adaptive thinking still varies per request; record the setting, not the spend |
| Container image digest | Read back after build, never the tag | Tags move; digests do not |
| CPU and memory limits, and host machine alias | Container arguments and `SHAKA_MACHINE_ALIAS` | Resource limits alone moved Terminal-Bench 2.0 by six points; the alias is private |
| Ruby version and gem lockfile hash | Fixture and runner lockfiles | |
| Pinned Actions revisions | Fixture workflow files | Tier 3 only; `N/A` otherwise |
| Hosted reviewer version | Action revision and, when reported, model | Tier 3 and product hosted-review evals only; `N/A` for tiers 1 and 2; `UNKNOWN` when a hosted reviewer ran and reported no model |
| Local reviewer CLI versions | `codex` and `claude-code` today, and any reviewer CLI added later | |
| Judge model id and judge prompt hash | Judge configuration | Dated model id, never an alias |
| Rate card version | `model-rates.yml` content hash | Repricing a stored record is allowed; it changes dollars, not tokens |
| Task bank version | Core benchmark commit | A changed task bank breaks comparability |

Decision. `eval/bin/shaka-eval diff A B --axis AXIS` compares two run sets only when
every fingerprint field except the named axis matches. The axes are:

- `skill`: two packages, everything else equal. The skill package digest and the
  workflow and enforcement hashes may differ together, since they are all part of
  the skill; every environment field must match. This is the only axis that gates.
  A skill change is judged within the cheap tier (both arms on the same cheap
  model) and separately within the strong tier.
- `model`: two model ids on the same host CLI and provider, with the same effort
  setting. Legal only within one host; a cross-vendor model change is a tier diff.
- `provider`: one model id served by two providers. When the served model id
  differs between arms, the diff is refused as a provider diff and offered as a
  tier diff. Serving infrastructure can change behavior on an unchanged model id,
  so even a same-model cross-provider diff carries that caveat on the card.
- `effort`: two effort or thinking settings on the same model.
- `tier`: the bundled comparison the thesis needs, cheap versus strong. Host CLI,
  provider, model, effort, and rate card entry are allowed to move together. A
  tier diff is labeled multi-variable on the card and never gates; it reports
  whether the cheap tier is close enough to the strong tier to be the product.

Any other difference refuses the diff and names the field. No surveyed framework
enforces a single-axis rule; they diff stored runs after the fact. Shaka enforces
it because the release gate depends on attribution.

Shipped: the offline [comparison guard](../../eval/comparisons.md) checks private
run sets against these axes, validates task and trial matching, and marks missing
fingerprint evidence provisional. It returns field names without private values.
Native Harbor records bind a digest of retained agent, verifier and sidecar
container readbacks; older Harbor records without it are provisional.
The [tier 2 wrapper](../../eval/harbor-trials.md) assembles all D2 fields from native
observations and explicit operator evidence. Missing observations remain `UNKNOWN`;
requested version pins cannot substitute for observed versions. The
[decision adapter](../../eval/decision-replays.md) reuses that capture for tier 1,
sets inapplicable fields to `N/A`, and binds the expected actions and checker code
in its criteria digest. Tier 3 capture, the diff card, statistics and release
verdict remain proposed.

### D3. Three task tiers by cost, and most of the budget on the cheap two

Decision. Tasks are one of three tiers.

| Tier | What the agent does | Needs GitHub | Typical wall clock | Grading |
| --- | --- | --- | --- | --- |
| 1, decision replay | Reads a scenario and the rendered workflow, returns a structured decision | No | Seconds | Exact match against the expected action list, as the merge-authorization eval does today |
| 2, artifact task | Starts in a container with a fixed diff, checks, and review context, and produces a PR description, walkthrough, review reply, squash message, or review findings | No | Minutes | Ruby publication validators first, judge second |
| 3, delivery task | Delivers a seeded change end to end against a fresh fixture repository with real pushes, checks, and walkthrough, under the proposal's contract | Yes | Up to one hour per arm | Protected verifier outside the agent container, GitHub readback, then judge on the published artifacts |

Tier 1 and tier 2 need no fixture repository and no credentials. They are the nightly
workload. Tier 3 is few, weekly by default, and is the only tier affected by the
public-versus-private fixture question.

Proposed, a named blocker for tier 2: `shaka description` and `shaka walkthrough`
measure prose limits on GitHub's rendered HTML and verify the walkthrough after it is
posted. For tier 2 to grade offline, the pure checks (required keys and sections,
managed region, table shape, link shape, head binding, forbidden literal newlines)
need an offline entry point, or the grader runs them against the script-backed fake
`gh` the test suite already uses. This is one bounded Ruby PR, it is the prerequisite
for the whole nightly workload, and it lands before any tier 2 task is admitted.

### D4. Ruby gates first; no judge call on a failed gate

Decision. Every trial passes a deterministic gate before any model judge runs. The
gate is the existing validators where they exist and small new checks where they do
not:

- Output schema and required sections, markers, and footers (Shipped validators).
- Every file path, line anchor, PR number, and check name in the artifact resolves
  against the diff and the recorded checks (Shipped for walkthrough links; Proposed
  for the rest). Claims the agent makes about tests or checks are compared with the
  runner's own results, never trusted from the text.
- Tier 3: the protected verifier runs the hidden tests in a clean, network-disabled
  container that the agent never had; changes to workflows, test commands, trusted
  policy, or other protected paths fail the trial even when CI is green. The
  proposal already specifies this; the known exploit class it prevents is a
  ten-line test shim or a replaced tool binary that makes every task pass.
- Forbidden actions (Proposed): any merge attempt without authority or any edit of
  protected paths, detected as the proposal describes; and grader-directed text,
  detected by a Ruby pattern list kept with the grader (phrases addressed to a
  judge, grader, or evaluator). The pattern list is a detector, not a proof of
  absence.
- Length bounds, secrets scan, and the existing forbidden-content patterns.

A gate failure ends the trial as `FAIL` with the reason, costs no judge tokens, and
counts as a failed trial for scoring (D8).

### D5. Judge protocol: pinned, separate family, fact-fed, calibrated, audited

Decision. A model judge is allowed only on trials that passed the gate, only on tier
2 and tier 3 artifacts, and only under these rules.

1. The judge is one pinned, dated model id from a different model family than the
   generator under test. It is the same model every night. It is not rotated with the
   generator, and the strong-tier generator is never a judge.
2. Two call shapes. Rubric calls score one artifact at a time: one call per rubric
   dimension per artifact, each a binary pass or fail with a one-line rule, a short
   critique, and an `Unknown` escape. Order has no meaning for a single artifact, so
   rubric consistency is measured by repeating a sample of calls and reporting the
   agreement rate. Pairwise calls compare the two arms' artifacts and run in both AB
   and BA order; a preference that flips with order is recorded as positional, not as
   a preference. Example dimensions for a PR description: states what changed, states
   why, names the verification, names the rollback, contains no claim the gate
   contradicts, is no longer than the task's reference.
3. The judge receives facts from Ruby: the diff summary, the gate results, the
   recorded check outcomes, and the resolved links. It never receives the candidate's
   own claims as facts.
4. Rubric results drive the score and the gate (D8). The pairwise result is reported
   as a trend on the card. Pairwise flips more under distracting features and can be
   intransitive; binary rubrics with a critique are more actionable and harder to game.
5. An anchor set of human-verdict pairs, kept private, is re-scored by the judge on
   every run. Agreement with the humans (reported as kappa and as true positive and
   true negative rates) is in every nightly summary. A drop beyond a stated bound
   marks the night provisional and points at judge drift rather than skill change.
   Once a week a human reads a sample of judge critiques; that read is the judge's
   audit.
6. A judge model deprecation notice triggers a planned re-baseline: the new judge
   scores the anchor set and the last clean release's stored artifacts before it
   scores a candidate. Stored artifacts exist so re-scoring needs no new agent runs.
7. When an arm shares the judge's family, which some provider and tier diffs force,
   the record says so, the self-preference risk is shown on the card, and the diff
   cannot gate without a human verdict sample.

Blind human verdicts (A better, B better, tie, both bad, with
a required reason, one per judge, hidden metrics until submitted), are the ground
truth. One validation bound applies everywhere: a rubric is validated when its judge
agrees with at least sixty human-labeled pairs at a stated kappa (0.6 is the starting
value). Sixty is the floor practitioners report for a usable judge validation set, with
about one hundred per failure mode as the target
([Husain](https://hamel.dev/blog/posts/llm-judge/)); this record applies the floor
per rubric, which is looser than per failure mode and is a starting point. Before
that, the rubric runs and its result is labeled advisory.

### D6. A human-blessed core benchmark and a proposed queue; never grade our own homework

Decision. Two task banks.

- `eval/core/` is the gating benchmark. A human admits every task. Admission
  requires: a reference solution that passes, a no-op or known-bad solution that
  fails, the verifier run three times with the same result, a difficulty band on the
  cheap tier of roughly 0.2 to 0.8 pass rate for capability tasks or near 1.0 for
  regression tasks, and a reviewer's sign-off recorded in the task file. Terminal-Bench
  2.0 kept 89 of 229 submitted tasks at about three reviewer hours each, figures
  reported in the task curation part of its [paper](https://arxiv.org/abs/2601.11868),
  not its abstract; expect the same ratio and cost.
- `eval/proposed/` is the queue. A PR that changes skill behavior adds its task
  here (D7). Proposed tasks run in that PR's eval and in the nightly as watch tasks.
  A watch task can block a release (D9) but can never make one clean, and it never
  joins the quality score until a human promotes it into core. Tasks written by the
  same model family that produced the change are the weakest evidence, which is why
  the queue exists and why the asymmetry holds.
- Hidden assets (reference solutions, hidden tests, rubric text that must not leak,
  the judge anchor set) live in a private repository in the eval organization, never
  in a fixture repository, never in the candidate checkout, and never under
  `shakacode/shaka`. Canary strings only address training corpora; an agent that can
  reach a repository can read it.
- The core bank is versioned. A gate run pins one bank version. A changed bank starts
  a new comparison series; scores across bank versions are not compared.
- The bank grows from failures: a maintainer correction, a reverted PR, a review
  finding that recurs, a failed real-work trial, or a keep-revise-drop report from
  `shaka trial report` becomes a proposed task with the original artifact as its
  reference. Fresh tasks are added on a stated cadence so the bank does not go stale.

Shipped: fixtures already carry a forbidden-content test that fails when a fixture
mentions a reference solution. That test extends to both banks.

### D7. Use 1: the PR eval

Decision. A PR that changes the skill package's rendered agent instructions ships
with the following evidence. This includes instruction changes in `SKILL.md`,
`workflow.yml`, and loaded references. A Ruby-only change or an enforcement-manifest
update that leaves those instructions unchanged does not trigger model trials.

1. At least one task in `eval/proposed/` whose reference artifact shows the intended
   improvement, or an explicit reason none applies (for example, a wording fix with
   no behavior claim). A PR with such a reason is covered by `bin/validate` and the
   core benchmark only.
2. One paired run on the cheap tier, axis `skill`: baseline is the merge-base
   package, candidate is the PR package, same night, same machine, same container
   limits, three trials per arm, on the PR's own tasks plus the core tasks the PR
   names as relevant.
3. One diff card (D10) in the PR, placed through the existing evidence conventions:
   the usage and provenance blocks already in the description, plus a comment
   carrying the card.

Acceptance on the cheap tier: the PR's own task scores higher for the candidate than
for the baseline; no regression task fails in any trial where the baseline passed in
every trial; no capability task set is flagged under D8; the one-sided lower bound
of the mean per-task score delta on the named core tasks is not below minus tau; and
the cache-neutral cost ratio is at or below 1.2, or the PR states why a higher cost
is worth it. A change that helps only the strong tier and hurts the cheap tier does
not pass; the thesis is that the cheap tier is the product.

CI runs only the free parts: task schema checks for the two public banks, the
existing instruction-growth report, and `bin/validate`. Model runs happen on the
the operator's host, and their records are posted as evidence. Changes to human
documentation or runtime Ruby alone need no model trials when rendered agent
instructions stay unchanged.

### D8. Scores, noise, repeats, and what counts as a regression

Decision, the score. Every trial has one quality score from 0 to 100, called points.

- Tier 1: 100 when the structured decision matches the expected action list exactly,
  else 0.
- Tiers 2 and 3: 0 when the gate fails. Otherwise 100 times the fraction of rubric
  dimensions the judge passed, with `Unknown` counted as not passed for the score and
  reported separately. A trial with more than a third of its dimensions `Unknown` is
  scored and also flagged as low-confidence on the card.
- A task's score for an arm is the mean over its K trials. The per-task delta is the
  candidate's task score minus the baseline's. The quality delta for a run set is the
  mean of per-task deltas over the tasks in the comparison, with its interval.
- Tier 1 and tier 2 tasks enter the same mean. Their mix is part of the bank version.

Decision, the defaults. The statistical defaults below are starting points. They
come from published agentic-eval variance figures and from a rough simulation run
during this record's research and retained with the research notes outside the
repository, not from Shaka data. The first ten nights of baseline-versus-baseline
data replace them, and the calibration method is one of the documents to write first.

- Tasks are classified `regression` (the baseline scored 100 in every trial over the
  last ten nights; before ten nights exist, the admission record decides) or
  `capability` (historical cheap-tier pass rate between 0.2 and 0.8). A regression
  trial fails when a tier 1 decision misses or a tier 2 or 3 gate fails; a judge
  dimension that flips is capability signal, not a regression failure. In practice
  the regression suite is tier 1 plus the tier 2 gate checks. Regression tasks gate
  on zero failures across K trials; one failure triggers a confirmation rerun with K
  more trials, and a failure in the rerun is a regression. Capability tasks gate on
  paired statistics.
- Repeats: K=3 per arm on cheap nights for tiers 1 and 2. K=8 to 10 on tier 1 for
  the weekly strong day and the release gate, where ten trials cost cents. Tier 2
  stays at K=3 and the release gate reads every night since the previous release.
  Tier 3 runs one trial per arm with counterbalanced order, as the contributor
  guide already requires.
- Pairing: the baseline is rerun every night on the same machine under the same
  limits; stored baseline scores are never reused as the comparison. In the research
  simulation, pairing roughly halved the standard error at this size, in line with
  the paired-difference recommendation in
  [Adding error bars to evals](https://arxiv.org/abs/2411.00640).
- Test: a one-sided sign-flip permutation test on per-task deltas, plus a paired
  bootstrap interval over tasks. No normal approximation; it underestimates
  uncertainty below a few hundred items.
- Noise floor: sigma_AA is estimated from the nightly baseline arm itself, split-half
  within a night and across nights, over at least ten nights. It resets whenever the
  model, image digest, or bank version changes. The image pins the host CLI version,
  so any CLI update requires a deliberate rebuild and resets the floor too.
- Two thresholds, with the relation stated. The flag threshold tau is for detection
  on a night or a PR: the larger of five points and 1.65 times sigma_AA, roughly eight
  points at K=3 on forty tasks. The release margin is for acceptance: ten points is
  the largest quality loss accepted in exchange for a cost or simplicity gain, and the
  release gate's lower bound must clear it with more trials behind it than one night has.
- Flag rule: a capability task set is flagged when p is below 0.05 and the mean
  delta is at or below minus tau. A flag triggers a confirmation rerun of the flagged
  tasks before anyone bisects.
- What this buys: the bank is about forty tasks, thirty in tier 1 and ten in tier 2.
  With K=3, one night detects a ten-point quality drop roughly half the time and a
  five-point drop rarely; two consecutive nights usually detect ten points, and the
  strong day with K=10 on tier 1 detects them reliably. Deterministic gate regressions and tier 1 regressions are
  detected in one night with near certainty. "Within about a day" is a promise
  about deterministic regressions and large judged regressions, not about small ones.
- Expect roughly one false flag every few weeks at these thresholds; the confirmation
  rerun exists to absorb that.

### D9. Use 2: the nightly batch and the release gate

Decision, the nightly. A scheduled job on a maintainer-controlled host invokes a small
eval skill, kept outside `skills/shaka/` so it never enters the product. The skill
does four things and nothing else: pull `main`, run `shaka-eval nightly`, read the
JSON summary, and post or append a public-safe summary to the tracking issue. Agent
instruction: the skill never edits skill files and never retries a failed arm. Ruby
enforces the budget: the runner reads the cap from its configuration, refuses a cap
above the configured maximum, and stops launching trials when the running
API-equivalent total crosses it. The Ruby does the rest:

1. Build or reuse the pinned image and read its digest.
2. On each of six cheap nights, run the core bank and every proposed task merged
   since the last clean release on the head package, cheap tier, K=3, tiers 1 and 2.
3. Rerun the last clean release package the same night on the same tasks as the
   paired baseline. This is the single largest cost lever and the single largest
   validity lever; the nightly keeps it.
4. On the seventh night, replace the K=3 cheap run with the strong tier at K=8 to 10
   on tier 1 and K=3 on tier 2. Run both head and release packages on the strong
   model for its paired baseline, and both packages on the cheap tier at the same K.
   This supplies the cheap skill-axis trajectory diff and the same-head tier diff
   (D2). The provider rotates on a fixed weekly order. A
   strong night is compared only within that night and against the previous
   strong-tier night of the same provider. The strong tier audits the cheap-tier
   conclusion; it is not a trend line across providers. When the rotating generator
   shares the pinned judge's family, D5 requires a human verdict sample before that
   strong-tier result can satisfy release condition 6.
5. Run tier 3 delivery tasks on the strong day only, or on a stated cadence, never
   on every night.
6. Write run records to the private results repository. Post to the tracking issue:
   the verdict, the per-task table with deltas, aggregate API-equivalent cost and
   wall-clock totals, the judge agreement on the anchor set, and links to the diff
   cards. Never post transcripts, machine aliases, per-run records, or hidden task
   detail.
7. Stop at the nightly cap, an API-equivalent figure computed from native usage
   records and the rate card as trials complete. The runner stops launching new
   trials when the running total crosses the cap, lets in-flight trials finish, and
   marks the night partial. Subscription-covered usage counts at API-equivalent
   rates. A partial night is not clean.

Decision, bisection. When a night is flagged and confirmed, the deterministic layer
bisects across the day's merged packages first, because tier 1 costs cents per
package and the current merge rate is about twelve PRs per day. Tier 2 bisects only
across the packages the deterministic layer could not separate.

Decision, what the gate covers. Of the PRs merged between two releases, the eval
gate covers those that changed skill behavior, which is the D7 trigger set. Ruby-only
and doc-only PRs are covered by `bin/validate` and the test suite at H, which the
gate also runs as its first condition.

Decision, the gate. A release candidate is a tagged head H. H is clean when all of
these hold against the previous release package R:

1. `bin/validate` passes at H.
2. Zero regression-task failures at H across the gate's K trials, after any
   confirmation rerun.
3. Two parts. First, the trajectory: no night since R was flagged under D8, where
   each night is its own skill-axis diff of that night's head against R. Second, H
   itself: on the release night, H versus R on the cheap tier, tier 1 at K=8 to 10
   and tier 2 at K=3, with the one-sided 95 percent lower bound of the mean per-task
   score delta at or above minus ten points. Successive heads are different packages,
   so nights are never pooled into one diff. This is a non-inferiority bound; "no
   significant difference" is not evidence of clean.
4. Cache-neutral cost ratio, geometric mean over paired tasks, at or below 1.2, or
   an explicit written acceptance of the higher cost.
5. Every watch task from a PR merged between R and H keeps its state. A task's state
   is "passing" when it scores above 50 in a majority of its K trials. A watch task
   that was passing in its PR eval and is not passing at H, after a confirmation
   rerun, blocks until a human disposes it: revert or fix the PR, or record that the
   task was wrong and drop it. This is the check that each merged PR made the right
   change and still works. A watch task can only block; it never adds to the score.
6. The most recent strong-tier night since R shows no flag. A release cut before
   the next strong-tier night inherits the previous strong-tier result and is
   labeled "strong tier not rechecked" on the tracking issue. The gate as written
   therefore rechecks the strong tier at most weekly, and a cadence faster than
   weekly accepts that label.
7. No `HARNESS_ERROR` on a gating task left unresolved, and harness errors below a
   stated share of trials overall.
8. No provisional run on a gating task: no `UNKNOWN` on a fingerprint field that
   matters to the comparison, and judge agreement on the anchor set within bound.
9. A human has read the diff cards for every flagged, changed, blocked, or newly
   promoted task and recorded the sign-off on the tracking issue.

Any other state is not clean. Inconclusive means rerun, not widen the window and not
lower the bound. During the first ten nights after a noise-floor reset, condition 3's
trajectory flag cannot be computed because tau has no floor behind it. The fixed
ten-point H-versus-R acceptance bound can still be computed. Such a release cannot
be called clean; any maintainer-approved exception is labeled "uncalibrated trajectory".

### D10. The diff is the product: one card, three readers

Decision. `shaka-eval diff` renders one card from two run sets. The same renderer
produces Markdown for PR comments and nightly summaries, and a single-file HTML page
for local review and for the product. The card has, in this order:

1. A header with the shared fingerprint and the one differing axis highlighted. A
   tier diff shows every bundled field. A provisional field is shown in its own
   color with the reason. The public renderings, PR comments and tracking-issue
   summaries, omit the machine alias and any private path; the full fingerprint
   stays in the private run record.
2. The verdict line: better, worse, no material difference, or inconclusive, with
   the interval, the number of tasks and trials, and the cost ratio.
3. A per-task table: gate result, score, each rubric dimension as pass, fail, or
   Unknown for each arm, the pairwise preference with its AB and BA agreement,
   tokens by category, cache-neutral dollars, billed dollars, and wall clock, for
   both arms, with the delta column colored only when it exceeds tau.
4. An artifact pane: the baseline and candidate PR description, walkthrough, or
   reply side by side with a word-level text diff, and the diff of the code change
   each arm produced when the tier has one. The reader should be able to judge in
   seconds whether the candidate's description is more useful, the way a visual
   regression tool shows expected, actual, and diff.
5. The human verdict control when the reader is a judge (product and anchor-set
   collection): blind until submitted, then revealed.

Existing tools provide parts of this view. Braintrust supports
[side-by-side output diffs and human pairwise verdicts](https://www.braintrust.dev/docs/evaluate/compare-experiments),
and LangSmith supports
[comparison of experiment results](https://docs.langchain.com/langsmith/compare-experiment-results).
Harbor's local viewer shows one run at a time (D15). Before building an HTML viewer,
evaluate whether an existing comparison view can consume the run records without
losing fingerprint enforcement, private-data boundaries, or the gate explanation.
The proposed CLI still needs a portable Markdown card for GitHub and local review.
Chromatic's baseline rule applies: a baseline moves only when a human accepts the
new result.

### D11. Use 3: user-defined comparisons

Proposed. A user-defined comparison reuses D1, D2, D4, D5, and D10 and adds the
following.

- A criteria set is how a user defines good output. Proposed fields: a name and
  version; the prompt type it applies to; a list of dimensions, each with a name, a
  one-line binary rule, and two or three labeled example pairs that seed the judge
  prompt; optional deterministic rules (must contain, must not contain, maximum
  length, must link); and the validation state (advisory or validated, with the
  count of human verdicts and the current kappa). The criteria set's hash joins the
  fingerprint. The judge prompt is built from the criteria set by the same Ruby that
  builds Shaka's own rubric prompts, so D5 holds unchanged. The seed examples are
  prompt material; validation still needs sixty human verdicts collected through the
  blind verdict flow over time.
- Frozen inputs. Both arms receive byte-identical inputs captured when the eval is
  created, so data cannot drift between the arms.
- Settings comparison on one axis per eval: provider, model, effort, or prompt
  version. A user who wants to compare two prompts on two models runs two evals.
- The reader's flow: blind side-by-side first, a human verdict with a reason,
  then revealed settings, metrics, and the judge's dimension results. Judge results
  are labeled advisory until the user's criteria set is validated, at which point
  the user can run evals unattended.
- Keys and budget: the operator supplies credentials and a daily cap. A same-family
  judge is advisory unless the D5 human-verdict requirement is met.
- Results contract: integrations exchange run records, diff-card JSON, and human
  verdicts rather than importing eval internals. Specific product designs are outside
  this record.

### D12. Cost accounting

Decision. Every record carries tokens by category and two dollar figures. The
primary comparison metric is cache-neutral dollars: all input priced at the base
input rate from the versioned rate card. The secondary is billed dollars with cache
reads and writes at their real rates. Cache state depends on timing and parallelism,
so billed cost moves without any code change; cache-neutral cost does not. Cost
deltas are paired per task as a log ratio and summarized as a geometric mean with a
bootstrap interval. Thinking tokens are billed in full by the provider and are
recorded as their own category. Token counts are not compared across model
generations with different tokenizers. Efficiency claims still require the
contributor guide's matched warm-up and counterbalanced order.

### D13. Fixture repositories

Decision. Tier 3 keeps the proposal's rule: one fresh repository per measured cell,
created from a template with a shallow clone at the base commit and no future refs,
retained afterward as history, with temporary access removed. Fixture repositories
stay in the dedicated eval organization, never in `shakacode`. Hidden assets never
enter them. The public-versus-private choice is open (see below); the tier split in
D3 confines its consequences to the weekly delivery tasks.

### D14. Where the code and records live

Decision. Runner, graders, fingerprint reader, diff renderer, and schema checks in
`eval/lib/shaka/evaluation/` with entry points in `eval/bin/`, tested with Minitest
under `test/` using the existing PATH-injected fake tools. Core and proposed task
banks under `eval/core/` and `eval/proposed/`, public-safe by construction and
checked by the existing forbidden-content test. The nightly skill under
`eval/skills/nightly/`. Hidden assets and run records in a private repository in
the eval organization. Public summaries on a tracking issue in `shakacode/shaka`.
Reports that a human writes still go to `eval/reports/` and the experiment index.
Whether the runner drives containers itself or wraps another tool is D15.

### D15. Two layers: Ruby comparison and Harbor execution

Decision. The comparison layer is Ruby. The maintainer selected Harbor for tier 2
after the [bounded spike](https://github.com/shakacode/shaka/blob/043a13d450f0111a98c9f8341ab7a366f8cef891/eval/reports/harbor-spike.md), with its tested
Codex upload adapter and sidecar ICMP restriction, on 2026-10-16.

- The comparison layer is the fingerprint match and single-axis rule (D2), the gates
  and judge protocol (D4, D5), the score and statistics (D8), the release gate (D9),
  and the diff card (D10). It is Ruby and lives under `eval/`. The surveyed tools
  provide comparison components, but not this complete contract. Existing viewers
  remain candidates for D10's presentation layer.
- The execution layer starts a container, installs a pinned host CLI, loads a skill
  revision, runs the agent at a set effort, enforces resource and network limits,
  collects artifacts, runs the verifier, and repeats K times. D1 and D14 describe a
  Ruby runner for it. Harbor now supplies tier 2 execution; the Ruby wrapper is
  still unbuilt. Tier 1 stays Ruby and tier 3 keeps its existing driver.

Harbor is an Apache-2.0 Python tool from the Terminal-Bench authors
([repository](https://github.com/harbor-framework/harbor)). The spike ran pinned
v0.24.0. Its report records both hosts, the adapters, isolation controls, cost,
and remaining limits. The capabilities below were verified in that version's
documentation and source:

- It ships agent integrations for Claude Code, Codex, Cursor, OpenCode, and Pi, the
  five hosts Shaka supports
  ([agents](https://docs.harborframework.com/agents/pre-integrated-agents)).
- One flag loads a skill from a local directory or from a Git repository at a branch
  or tag. It does not accept a raw commit id. The job lock file records each skill
  by name and content digest, plus the commit a branch or tag resolved to
  ([skills](https://docs.harborframework.com/jobs/skills)).
- A task can run its verifier in a separate sandbox with explicit artifact handoff,
  and can turn network access off or restrict it to an allowlist
  ([separate verifier](https://docs.harborframework.com/tasks/separate-verifier),
  [task configuration](https://docs.harborframework.com/tasks/configuration)).
- It repeats attempts per task. Its Docker environment applies CPU and memory limits
  when the task declares them and leaves sizing to Docker when it does not
  ([resources](https://docs.harborframework.com/tasks/resources)).
- The host CLI version can be requested, and an image that already holds that
  version skips the install. A requested version is recorded as requested; an
  unrequested one is read back from the CLI. Effort is an option on the Claude Code
  and Codex integrations.
- API keys are the default. Subscription sign-in is opt-in on both of those
  integrations.
- It can rerun a changed verifier over recorded outputs without rerunning the agent
  ([regrade](https://docs.harborframework.com/jobs/regrade)), and its Rewardkit
  package offers weighted binary criteria and repeated judge samples with an
  agreement score
  ([judge criteria](https://docs.harborframework.com/rewardkit/judge-criteria)).

What it does not provide, checked the same way:

- No paired diff, single-axis rule, noise floor, gate, or side-by-side view. That is
  the comparison layer.
- No container image digest in the lock file or trial result. It also removes the
  locally built image after a trial by default, so the wrapper reads the image id
  before teardown.
- Token counts as input, cached, and output with a cost. The cache-write and
  reasoning categories D12 needs still come from `shaka usage` reading the native
  session logs.
- The proposal's isolation recipe. Its default container has no init process and
  drops no capabilities, and it copies the skill into the agent's own configuration
  directory, where the agent can change it. The proposal's lessons on process
  reaping and a read-only trusted skill still apply.
- The tier 3 driver. The proposal's driver posts head-bound reviews during the run
  and reads GitHub state back. Tier 3 stays on that driver, and the spike does not
  test it.

Rules that hold whenever Harbor runs here. Proposed, enforced by the Ruby wrapper
that launches it, and set by hand for the spike, which runs before the wrapper
exists:

- Telemetry is off. By default Harbor reports each job's agents, models, token
  usage, cost, and reward to a third party
  ([usage stats](https://docs.harborframework.com/telemetry/telemetry)). Per-run
  records are private here, so the wrapper sets `HARBOR_TELEMETRY=off`.
- No uploads to Harbor Hub. Results stay in the private results repository.
- The Harbor version is pinned and joins the fingerprint. It is a 0.x tool with
  frequent releases.
- The wrapper always requests a host CLI version, builds it into the image, and
  confirms it against the session log. Harbor installs the latest when none is
  requested.
- The wrapper passes only the credential for the chosen sign-in mode. Harbor
  forwards a Claude subscription token found in the environment even when an API
  key is in use.
- Harbor is a tool on the eval machines. It never becomes a dependency of the gem
  or the skill.

The spike. Two prerequisites: the maintainer accepts a pinned Python tool on the
eval machines (question 12) and names the sign-in mode (question 10). The task is
one existing merge-authorization scenario, because its grader is the one eval
grader that runs offline today. The agent loads the Shaka skill, writes its
decision as JSON, and a separate verifier runs the existing
`eval/bin/merge-authorization check` on it. That exercises the tier 2 execution
path without waiting for the D3 offline entry point. The two arms are the baseline
and repaired workflow revisions recorded in the
[merge-authorization report](https://github.com/shakacode/shaka/blob/main/eval/reports/ask-merge-authorization.md),
loaded from two local checkouts, on Claude Code and Codex, three attempts each. The
cap is two working days; a spike that cannot finish inside the cap is a negative
result. It passes when all of these hold:

1. Both hosts complete the task, and the lock file's skill digest for each arm
   matches that revision's skill tree.
2. The verifier runs in its own sandbox, and the grader and expected answers are
   absent from the agent's container.
3. Harbor's lock file and trial result supply the skill digest, task digest, host
   CLI version, provider, model, effort setting, declared CPU and memory, and its
   own version. The wrapper can supply the rest of D2: image digest, workflow and
   enforcement hashes, routed model, Ruby and lockfile hash, and machine alias.
4. `shaka usage --file` reads the collected native session logs and returns the D12
   token categories.
5. The chosen sign-in mode works on the eval host without any other credential
   entering the container.
6. With the host CLIs built into the image, the agent phase runs under an allowlist
   of model endpoints only, a request to any other host fails, and a host-side
   capture shows no request to the telemetry service or the hub.
7. Each gap against the proposal's isolation recipe is either closed by task or
   compose configuration or listed as an accepted loss for tier 2.

The report recommends and the maintainer decides. The earlier merge-authorization
run scored the two revisions 3 of 8 and 8 of 8 with the workflow embedded in the
prompt; seeing that gap again through skill loading is a useful signal, not a pass
condition. With Harbor selected, `shaka-eval run` will wrap a Harbor job and convert
its result into the run record; tier 2 tasks take
Harbor's task layout; and the probe container builder and proxy sidecar give way to
Harbor for that tier only where condition 7 allows. Tier 1 needs no container and
stays plain Ruby.

## Budget

The maintainer approved pilot caps on 2026-10-16: $200 per month in total,
$5 per night, and $15 per PR evaluation, all in API-equivalent dollars.
Judges, retries, and tier 3 count toward the monthly total; tier 3 runs manually
at first. The shared monthly cap takes precedence. These caps fund a smaller
initial bank than the full workload estimated below; a partial night is not clean
under D9.

Shipped: the [budgeted Ruby batch core](../../eval/budget-runner.md) requires
explicit operator limits, retains unresolved calls across one private account, and saves
validated records before settling charges. It requires a trusted executor callback.
The [native usage adapter](../../eval/native-usage.md) converts collected Harbor
JSONL sessions through the installed usage command and reprices cache-neutral
dollars. The [Harbor trial API](../../eval/harbor-trials.md) supplies a reservation-bound
single-trial launcher for operator-prepared tasks, with native accounting and owned-resource
cleanup and D2 assembly from native observations plus explicit operator evidence.
Capture for other tiers, grading, paired statistics, release-gate consumers and
scheduled execution remain unbuilt.

All figures are cache-neutral (D12), at the rate card's base input and output rates
as verified in September 2026, and are planning references to be replaced by the
first measured nights. Named example models: the cheap tier is Claude Sonnet 5 or
gpt-6.1-sol, both $2 per million input tokens and $10 per million output; the strong
tier is Claude Opus 5.5 ($4 and $20) or gpt-6-astra ($10 and $50); the judge is
whichever cheap-tier model is from the other family. Per-trial assumptions: a tier 1
trial carries 30 thousand input tokens and 500 output tokens, matching the roughly
29 thousand per session the merge-authorization replay recorded; a tier 2 trial
carries 300 thousand input and 6 thousand output tokens, an assumption with no
measurement yet; a tier 3 arm on the cheap tier cost $2.42 to $3.45 in the two
recorded pairs at gpt-6.1-sol and medium effort, under a $10 soft stop, and the
strong tier is unmeasured and assumed at three times that for either strong model;
a judge call carries 15 thousand input and 500 output tokens, and a pair needs about
twelve calls (five dimensions for each of two artifacts, plus pairwise in two
orders), about $0.40.

| Run | Trials or calls | Cheap tier | Strong tier, Opus 5.5 | Strong tier, gpt-6-astra |
| --- | --- | --- | --- | --- |
| Tier 1 trial | 1 | $0.07 | $0.13 | $0.33 |
| Tier 2 trial | 1 | $0.66 | $1.32 | $3.30 |
| Cheap night: 30 tier 1 tasks, K=3, two arms | 180 | $12 | | |
| Cheap night: 10 tier 2 tasks, K=3, two arms | 60 | $40 | | |
| Cheap night: judge calls on about 30 passing pairs | 360 | $13 | | |
| Cheap night total | | about $65, 2 to 3 hours | | |
| Strong night: tier 1 at K=8, two arms | 480 | | $62 | $156 |
| Strong night: tier 2 at K=3, two arms | 60 | | $79 | $198 |
| Strong night: judge calls, 30 pairs | 360 | | $13 | $13 |
| Strong night: two tier 3 tasks, one trial, two arms, see note | 4 | | $30 to $40 | $30 to $40 |
| Strong night: paired cheap packages for trajectory and tier diffs, trials plus judge calls | 540 + 360 | | about $84 | about $84 |
| Strong night total | | | about $275, a working day | about $485, a working day |
| Week, six cheap nights and one strong | | | about $665 | about $875 |
| Month, 30 days | | | about $2,850 | about $3,750 |
| Release-night cheap comparison at K=8 on tier 1, K=3 on tier 2, including judge calls | 540 + 360 | about $84 | | |
| One PR eval: 8 tier 1 and 4 tier 2 tasks, K=3, two arms | 72 | about $20 to $25, under an hour | | |

Note on the tier 3 row: it is three times the measured cheap-tier cost for both
strong models, so the two columns match by construction and say nothing about how
tier 3 cost varies by model. Scaled by the rate card instead, the row would be about
$19 to $28 for Opus 5.5 and $48 to $69 for gpt-6-astra. Like for like, that moves
a strong night total by under $30 and a month by under $130.

The table prices one cheap series and one strong series. A second cheap model run
nightly doubles the cheap night and needs its own pinned judge from the other family.
The release-night row replaces a scheduled cheap comparison at those settings. If
run separately, add its full cost to the weekly and monthly estimates.

Levers, in order of effect: the number of tier 2 tasks and their K on both cheap
and strong nights (tier 2 is about half of every total); the strong-tier choice
of model (astra doubles the strong night); running the judge on one batched call per
artifact instead of one per dimension (cuts the judge line by two thirds at some
cost to rubric isolation); and tier 3 cadence (small, since tier 3 is under $40 a
week at these estimates). A lean configuration of tier 1 at K=3, five tier 2 tasks
at K=2, and a strong night every other week is about $30 a cheap night and about
$1,300 a month. Subscription-covered hosts may make some trials free at the margin;
the contributor guide's rule stands that subscription access is not an assertion
that inference is free, and usage is recorded as API-equivalent either way. The
human question is the cap, not whether there is one.

## Tradeoffs

- Nightly on maintainer-controlled hosts instead of CI keeps paid benchmarks out of CI and
  keeps credentials off shared runners, at the cost of machine heterogeneity. The
  fingerprint records the machine and limits; it does not control them. Pairing the
  baseline on the same machine the same night is the mitigation, and the reason
  stored baseline scores are never reused.
- A small benchmark that a fixed budget can afford resolves about ten points a night
  and about five points a week. Practice runs hundreds of tasks and five to ten
  repeats and still reports standard deviations of one to two points at
  temperature zero. This record accepts the coarser resolution, leans on the
  deterministic near-100 percent regression suite for the daily promise, and uses
  non-inferiority bounds instead of claims of equivalence.
- The cheap tier gates and the strong tier audits. A skill change that only helps
  strong models is rejected. That is the thesis, and it is also the risk: if the
  cheap tier turns out not to be the product for most users, the gate is pointed at
  the wrong target. The strong-tier night and the tier diff keep evidence for that
  reversal.
- A pinned judge from a different family costs an extra vendor relationship and a
  re-baseline on every deprecation. The alternative, rotating or same-family judges,
  has measured self-preference lift and injects drift into the series.
- Three tiers mean three graders to maintain. The alternative, delivery tasks only,
  is what the proposal planned, and two inconclusive hour-long pairs showed its
  cost per bit of evidence.
- Single-axis diffs refuse many comparisons people want to make, and the tier diff
  that the thesis needs is explicitly multi-variable and non-gating. The alternative,
  multi-axis diffs with regression-style attribution, needs far more runs than the
  budget allows.
- Posting public summaries while keeping records private means two renderings and
  one more place for the maintainer to look. The alternative, public run records,
  publishes machine identities and hidden-task detail.
- Watch tasks that can block but never pass protect against grading our own
  homework at the cost of a human disposition step on every blocked release.

## Where common practice disagrees with this design

- Scale. Published practice uses hundreds of tasks and five to ten repeats
  ([Miller](https://arxiv.org/abs/2411.00640),
  [On Randomness in Agentic Evals](https://arxiv.org/abs/2602.07150),
  [Terminal-Bench 2.0](https://arxiv.org/abs/2601.11868)). This design uses about
  forty tasks and three repeats on cheap nights. D8 states the resolution that buys.
- Pairwise as the gate. Pairwise judging is widely recommended
  ([OpenAI](https://developers.openai.com/api/docs/guides/evaluation-best-practices)),
  but it flips more under distracting features
  ([Tripathi et al.](https://arxiv.org/abs/2504.14716)) and can be intransitive
  ([TrustJudge](https://arxiv.org/abs/2509.21117)). D5 gates on per-dimension binary
  rubrics and reports pairwise as a trend.
- Calendar rotation. Practice escalates to a strong judge on low confidence or uses a
  panel ([Trust or Escalate](https://arxiv.org/abs/2407.18370),
  [PoLL](https://arxiv.org/abs/2404.18796)). This design rotates the strong
  generator weekly as an audit and keeps the judge fixed. The generator rotation
  confounds model, provider, and day, so D9 compares strong-tier nights only within
  a night and within a provider series.
- Judge vendor. Anthropic's guidance uses a different grading model than the
  generator ([develop tests](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests));
  measured same-family lift ranges from a few points to twenty-five
  ([Zheng et al.](https://arxiv.org/html/2306.05685v4),
  [Panickssery et al.](https://arxiv.org/abs/2404.13076)). D5 requires a different
  family and names the exception.
- Stored baselines. Braintrust and LangSmith compare against a stored experiment
  ([compare experiments](https://www.braintrust.dev/docs/evaluate/compare-experiments),
  [LangSmith](https://docs.langchain.com/langsmith/compare-experiment-results)).
  Provider drift on an unchanged model id
  ([model ids and versions](https://platform.claude.com/docs/en/about-claude/models/model-ids-and-versions)),
  time-of-day effects, and resource limits
  ([infrastructure noise](https://www.anthropic.com/engineering/infrastructure-noise))
  argue for rerunning the baseline nightly. D9 does.
- Persistent fixture repositories. Agents have read future commits with
  `git log --all` ([SWE-bench issue 465](https://github.com/SWE-bench/SWE-bench/issues/465))
  and exploited leaked solutions at high rates without safeguards
  ([Ludwig et al.](https://arxiv.org/abs/2609.06780)). D13 uses a fresh shallow
  repository per cell with no future refs.
- Grading on the PR head in CI. A ten-line test shim resolved every SWE-bench Verified
  instance and a replaced `curl` scored every Terminal-Bench task
  ([Berkeley RDI](https://rdi.berkeley.edu/blog/trustworthy-benchmarks-cont/)).
  D4 grades in a container the agent never had, with hidden tests. Harbor offers
  the same remedy as an opt-in separate verifier sandbox (D15).
- Author-shipped tasks. Tests written by the same model are homogeneous
  ([SAGA](https://arxiv.org/abs/2507.06920)); self-improving loops reward-hack more
  as optimization continues ([ICLR 2026](https://iclr.cc/virtual/2026/10018648)).
  D6's queue never adds to the score until a human promotes.
- Score-delta gating on small suites. Anthropic separates capability evals that
  start low from regression evals near 100 percent
  ([demystifying evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)).
  D8 classifies tasks the same way and gates regression tasks on zero failures.
- Claude Code's plugin evals. `claude plugin eval` offers six graders, a with and
  without plugin ablation, three trials by default, and a JSON report with cost and
  mean delta ([plugin evals](https://code.claude.com/docs/en/plugin-evals)). It runs
  only on Claude, needs session auth, cannot load a Git fixture's project
  configuration, and has no run-versus-run diff. This design borrows its grader
  vocabulary and does not depend on it.
- Framework fingerprints. Inspect records dependency versions and the git revision
  ([Inspect eval logs](https://inspect.aisi.org.uk/eval-logs.html)). Harbor records
  its own version, the task digest, each skill's digest, the agent CLI version, and
  the declared CPU and memory settings (D15). Neither was found to record the
  container image digest. D2 records it.

## Known pitfalls in this plan

- Sampling cannot be pinned. Newer Anthropic models reject non-default temperature
  ([migration guide](https://platform.claude.com/docs/en/models/opus-5-5/migration-guide)),
  temperature zero was never a determinism guarantee, and batch-size effects alone
  produce many distinct completions
  ([Thinking Machines](https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/)).
  Pair by task, never by seed, and plan for K greater than one.
- Cache state is timing-dependent. A cache entry exists only after the first
  response begins, so parallel trials miss it
  ([prompt caching](https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching));
  changing effort invalidates the cache
  ([thinking and cost](https://platform.claude.com/docs/en/build-with-claude/thinking-steering-and-cost)).
  Billed cost moves on its own; D12's cache-neutral metric is the comparison.
- Office machines. Resource configuration alone moved Terminal-Bench 2.0 by six
  points ([infrastructure noise](https://www.anthropic.com/engineering/infrastructure-noise));
  a laptop on battery moved a microbenchmark by about forty percent
  ([Criterion](https://bheisler.github.io/criterion.rs/book/user_guide/command_line_output.html)).
  Pin container limits, record them, and pair on the same machine.
- Judge prompt injection. The judge reads text the system under test wrote;
  optimized suffixes reach high false-positive rates on some judges
  ([JudgeDeceiver](https://arxiv.org/abs/2403.17710),
  [One Token](https://arxiv.org/html/2507.08794v1)). D4 fails grader-directed text and
  D5 feeds facts from Ruby.
- Verbosity cuts both ways. Judges reward length
  ([Zheng et al.](https://arxiv.org/html/2306.05685v4)); practitioners penalize
  verbose, AI-toned PR text
  ([Mariotto et al.](https://conf.researchr.org/details/esem-2025/esem-2025-industrial-track-/4/From-Assessment-to-Enhancement-of-Pull-Requests-at-Scale-Aligning-Code-Reviews-with-)).
  The core bank needs tasks where the shorter artifact is the reference, and D5's
  example dimensions include one.
- Judge and generator retirements. Anthropic gives at least sixty days notice
  ([deprecations](https://platform.claude.com/docs/en/about-claude/model-deprecations));
  OpenAI at least six months for GA models
  ([OpenAI deprecations](https://developers.openai.com/api/docs/deprecations)).
  A retirement inside a comparison series ends the series; stored artifacts allow
  re-scoring without new agent runs.
- Noisy evals miss real degradation. Anthropic's own postmortem says its evals
  did not catch a routing bug affecting a large share of requests
  ([postmortem](https://www.anthropic.com/engineering/a-postmortem-of-three-recent-issues)).
  A clean gate is evidence, not proof; real-use acceptance in the requirements stays.
- Skill invocation itself is unreliable. One vendor measured skills used about
  seventy percent of the time when prompted
  ([LangChain](https://www.langchain.com/blog/evaluating-skills)). Tier 2 tasks must
  check that the skill was loaded, separately from output quality.
- Task bank drift. Terminal-Bench 2.1 repaired 28 of 89 tasks and one agent pair
  moved twelve points ([Terminal-Bench 2.1](https://www.tbench.ai/news/terminal-bench-2-1)).
  Bank versions are in the fingerprint and never compared across.
- Criteria drift in the product. People refine their criteria only after seeing
  outputs ([EvalGen](https://arxiv.org/pdf/2404.12272)). D11 keeps a user's judge
  advisory until sixty verdicts exist.
- Weekly false flags. At alpha 0.05 nightly, roughly one week in three has a false
  flag somewhere. D8's confirmation rerun is the absorber; without it, bisection
  spend is wasted.
- Hosted reviewer version is unknown today. The review action is pinned by revision
  and reports no model. Any tier 3 run that depends on it is provisional until the
  action reports one or the eval records the model it observed.
- Host CLI auto-updates. The probe image ships Ruby, git, and the GitHub CLI; the
  host CLI is not pinned there today. D8 requires the image to pin it, or the
  noise-floor window never closes. Harbor installs a requested CLI version when one
  is given and the latest otherwise, so the wrapper always requests one (D15).

## Alternatives considered

- Adopt `claude plugin eval` as the system. Rejected as the system; borrowed as
  vocabulary. It cannot run Codex or other hosts, cannot drive a Git fixture with
  project configuration, has no run-versus-run diff, and publishes by default.
- Adopt Inspect, promptfoo, or Braintrust as the system. Rejected. None enforces
  the single-axis rule, produces the gate, or records the image digest, and
  promptfoo and Braintrust treat the system under test mainly as a function that
  returns text. An earlier draft also rejected them for adding a non-Ruby
  dependency. That reason was too broad: the repository rule bars a new runtime gem
  and eval code in the product runtime, and a tool on the eval machines breaks
  neither. promptfoo's custom providers and Braintrust's beta Ruby SDK are noted
  as future adapters if a user wants their results in those tools.
- Adopt Harbor as the execution layer. Not rejected and not adopted. It fits the
  execution layer better than the three above because it ships integrations for
  all five hosts and loads a skill from a local checkout or a Git ref. D15 sets a
  spike; the maintainer decides after it.
- Build the execution layer in Ruby, as the proposal planned. Held until the D15
  spike reports.
- Delivery tasks only, as the proposal planned. Rejected as the daily workload.
  Two hour-long pairs produced inconclusive value evidence; tiers 1 and 2 produce
  more bits per dollar.
- Judge-free, human-only comparison. Kept as the ground truth and rejected as the
  only mechanism. The maintainer's attention is the scarcest resource; the judge
  scales the human's labeled verdicts.
- Store baseline scores and compare the candidate against them. Rejected for the
  drift and infrastructure reasons above.
- Gate in CI on every PR with model runs. Rejected. Paid benchmarks stay out of CI;
  the merge rate would cost more than the nightly and would still not pair arms on
  the same machine.
- Let a PR's own task count toward the release score. Rejected; it is grading our
  own homework. Watch tasks block only.

## Consequences

- Every PR that changes skill behavior takes longer to land: a task to write and a
  paired run to execute, and a human to promote the task later. The queue keeps the
  PR path unblocked by the promotion step.
- A private repository, a tracking issue, and a scheduled host job become part of
  the maintainer's routine. Someone reads the nightly summary every morning.
- The first ten nights establish the noise floor. The fixed release acceptance
  bound is available, but the trajectory rule is uncalibrated. Any release exception
  in that window requires maintainer approval and the explicit label in D9.
- A judge deprecation or a bank change starts a new series. Trend charts restart.
- A release cadence faster than weekly ships with "strong tier not rechecked" on
  most releases. A weekly cadence on the strong-tier day avoids that label.
- User-defined comparisons need frozen inputs, versioned criteria, and blind human
  verdicts; they do not authorize changes to any separate product.
- This proposed design stays under `internal/` with the public development records.
  It does not appear on the docs site. Company plans, hidden assets, and private run
  records belong outside this public repository.

## Open decisions

1. Fixture repository organization and visibility. The question is tier 3 only.
   Options: keep public repositories and accept that solved cells leak into the
   public record and into training data, with hidden assets private; move measured
   cells to private repositories on a paid Team plan, which restores GitHub-required
   checks and adds a per-seat price to confirm; or use private repositories on the
   Free plan with seam-declared required checks and the harness as the only gate,
   which [PR #236](https://github.com/shakacode/shaka/pull/236) made possible for
   Ask mode. Recommendation: public cells for mechanics qualification, Free-plan
   private cells with seam-declared checks for Ask-mode measured cells now, and a
   paid plan only when an Auto-merge cell needs GitHub-enforced protection. This
   revisits the proposal's "paid plan before measured cells" decision, which
   predates PR #236.
2. Results store. A private repository in the eval organization, a private branch,
   or local disk with a published summary. Recommendation: a private repository,
   so records survive machine changes and integrations can read them.
3. Release candidate definition and cadence. A tagged head on a fixed weekly cadence
   on the strong-tier day keeps the bisection window bounded and avoids the "strong
   tier not rechecked" label; "about 20 PRs" at the current merge rate is every two
   days, which the gate allows with that label.
4. Judge family per generator family, and whether a judge is allowed in the release
   gate at all before the anchor set reaches the validation bound. Recommendation:
   deterministic plus human until then; judge advisory.
5. Which cheap models and which strong models, and the weekly provider rotation order.
6. Nightly and weekly caps, and the per-PR cap, as API-equivalent dollars.
7. Whether tier 3 runs weekly, every other week, or only before a release.
8. The scheduling host and credential storage for the eval operator.
9. The interchange schema for integrations reading run records and diff cards.
10. Who may promote a proposed task into core, and how many reviewer hours per task
    the budget funds.
11. How a user-defined comparison records an advisory same-family judge result.
12. Resolved on 2026-10-16: Harbor for tier 2, with the spike's tested upload adapter
    and ICMP restriction. The maintainer accepted the recommendation after the
    [report](https://github.com/shakacode/shaka/blob/043a13d450f0111a98c9f8341ab7a366f8cef891/eval/reports/harbor-spike.md); D2's provisional-evidence rules remain.

## Questions a human must answer before we build

1. Resolved on 2026-10-16: $200/month including tier 3, $5/night, and $15/PR;
   judges and retries count toward the total, and tier 3 runs manually initially.
2. Which two cheap models and which two strong models form the first series, and in
   which provider order does the strong tier rotate?
3. Which model family is the judge, and is a third family available for provider-axis
   diffs?
4. Public, Free-plan private, or paid private for tier 3 measured cells?
5. What is the release cadence, and is a release candidate a tag the nightly creates
   or one the maintainer creates?
6. Which existing artifacts seed the core bank: which past PRs, which review
   findings from `internal/review-outcomes.md`, which trial reports, and which
   maintainer corrections?
7. Who, besides the maintainer, may record a human verdict or promote a task?
8. Does the first ten-night calibration period gate releases on the deterministic
   conditions alone, or does no release happen until the noise floor exists?
9. Which user-defined comparison criteria and verdicts may be shared? Default to
   private records unless their owner explicitly authorizes publication.
10. Does the nightly skill run under a subscription or under API keys, with usage
    reported as API-equivalent either way?
11. Which parts of an implemented evaluation system need a human-facing guide?
    Keep proposed development records under `internal/`; publish a guide when the
    behavior exists.
12. Resolved on 2026-10-16: pinned Harbor is accepted with telemetry disabled and
    no Hub uploads; D15 records the required adaptations.

## Documentation to read first

- [Local evaluation proposal](https://github.com/shakacode/shaka/blob/main/internal/local-evaluation-proposal.md):
  isolation recipe, two-message startup, terminal states, grading contract.
- [Evaluating changes](https://github.com/shakacode/shaka/blob/main/contributing/evaluating-changes.md):
  run-card defaults, the three conclusions, what inconclusive means.
- [Experiment index](https://github.com/shakacode/shaka/blob/main/eval/README.md)
  and the three reports under `eval/reports/`.
- [Try a Shaka PR on real work](../../docs/trying-pr-versions.md),
  [PR verification](../../docs/pr-verification.md), and
  [usage and cost](../../docs/reference/usage-and-cost.md): what a Shaka PR must show and
  how usage is recorded.
- [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
  and [infrastructure noise](https://www.anthropic.com/engineering/infrastructure-noise).
- [Adding error bars to evals](https://arxiv.org/abs/2411.00640) and
  [On randomness in agentic evals](https://arxiv.org/abs/2602.07150).
- [Creating an LLM-as-a-judge that drives business results](https://hamel.dev/blog/posts/llm-judge/)
  and the [evals FAQ](https://hamel.dev/blog/posts/evals-faq/).
- [Terminal-Bench 2.0](https://arxiv.org/abs/2601.11868) for task admission, and
  [Trustworthy benchmarks](https://rdi.berkeley.edu/blog/trustworthy-benchmarks-cont/)
  for grader isolation.
- [Claude Code plugin evals](https://code.claude.com/docs/en/plugin-evals) for the
  grader vocabulary.
- Harbor's [task format](https://docs.harborframework.com/tasks/overview),
  [separate verifier](https://docs.harborframework.com/tasks/separate-verifier), and
  [skills](https://docs.harborframework.com/jobs/skills) pages, before the D15 spike.

## Documentation to write first

Before the list below, run the D15 spike and write its report under `eval/reports/`
with an entry in the experiment index. Its result decides the task format in item 3.
Items 1 and 2 are needed either way.

1. The run record schema and the fingerprint field list, as a JSON schema under
   `eval/` with a Ruby check.
2. The offline entry point for the publication validators (the D3 blocker), as a
   short design note with the list of checks it exposes.
3. The task format for each tier, including the admission checklist and the
   difficulty band, under `eval/core/README.md`.
4. The judge protocol as an agent-facing procedure, with the rubric dimension
   format, the call shapes, and the anchor-set handling.
5. The noise-floor calibration method: how sigma_AA is computed from the first ten
   nights and how tau is recomputed.
6. The diff card specification with one rendered example per use.
7. The nightly runbook: machine setup, credentials, the skill's four steps, the
   cap, and what to do on a flag.
8. The release gate checklist that the tracking issue comment follows.
9. The product criteria guide: how a user writes a criteria set and labels its
   example pairs.
10. An update to the contributor guide that points PR authors to the proposed queue
    and the PR eval.

## Sources

Research for this record was gathered on 2026-10-07. Primary sources are linked
inline above. Figures quoted from papers read only as abstracts are marked in the
research memos retained outside this repository and were not used for any gate
threshold; the thresholds in D8 are starting points to be replaced by measured
baseline-versus-baseline data.
