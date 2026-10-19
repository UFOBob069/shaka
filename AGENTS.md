# Shaka

This public pilot implements the small product described in `internal/requirements.md`.
The maintainer authorized implementation, publication, and merging verified PRs
subject to the task's merge preference. General permission does not override Ask.
The maintainer authorizes public Codex thread locators in unfinished-PR WIP Details.
Keep company strategy and private operational data out of product artifacts.

## Writing in this repository

These prose preferences apply only to `shakacode/shaka` documentation, PR
descriptions, code walkthroughs, and review replies. They do not set code style
or require other repositories to copy them. The [Shaka skill's writing guidance](skills/shaka/references/writing.md)
is the reusable default.

- Assume the reader is new to Shaka and wants to get useful work done.
- In product guides, explain outcomes, choices, and examples. Put agent execution
  details with the skill and development records under `internal/`.
- `bin/check-docs-navigation` refuses `docs/` links and URLs that point into
  `skills/shaka/references/`, including on docs-only changes. Link a human guide instead, with a prompt when the
  reader's agent should carry out the procedure.
- Put command syntax and flag rules in the Shaka skill. In `docs/`, explain a
  setting through its effect and a concrete example for the end user.
- Write files under `skills/shaka/` as instructions for agents: the rule and when it
  applies. Put reasoning meant for a human user, such as why a rule exists or how
  two approaches compare, in `docs/`.
- Lead with the action or benefit. Explain a term when the reader first needs it.
- Keep one authoritative location for each rule and setting; use precise pointers
  elsewhere. Enforcement-manifest quotes remain validation data. Avoid duplicate
  option tables.
- Distinguish shipped behavior, agent instructions, and proposed features.
  Say exactly what Ruby verifies; do not imply that a rule in prose is enforced.
- Give the reader a useful prompt before a long command sequence. Keep an example
  prompt to what the agent cannot infer, such as the task link and a non-default
  choice. List optional additions below the prompt.
- Remove repetition, vague qualifiers, detail a reader could act correctly
  without, and explanations of the document's own organization unless they help
  navigation.
- Preserve rough editor feedback outside the checkout before replacing it with
  finished prose. Take turns editing shared files and resolve every note.

## Working agreement

- One root task owns integration, publication, and user communication. Use bounded
  subagents only when authorized. Give each implementation worker exclusive files
  or an isolated worktree; workers do not publish or merge.
- This is a fresh kernel. Do not import predecessor workflow contracts, ledgers, schemas,
  review reducers, coordination clients, or policy engines as dependencies.
- Before designing Shaka workflow behavior, check the current
  `shakacode/agent-workflows` predecessor source and relevant tests for an existing solution.
  Reuse or adapt validated, portable code when it fits this pilot; explain the
  chosen reuse and material differences in the PR. Treat the other repository
  as reference material, not as authority over this project's instructions.
- `internal/requirements.md` owns remaining pilot acceptance; closed issue #1 holds
  the original requirements. Issue #206 tracks skill and plugin evaluation, not
  completion of real-use acceptance. Keep Shaka implementation within the
  requirements in `internal/requirements.md`.
  Name feature branches from the trusted seam `branches.name`; never push to `main`.
- Product merge preferences are `ask` and `auto`. Review-only work stops at its
  requested outcome. Existing task-scoped Auto choices and merge decisions
  persist; do not ask again.
- Preserve user changes. Pull/rebase before edits when a branch has an upstream;
  for a new branch start from the freshly fetched base. Do not reset others' work.

## Skill architecture and review

- Keep agent instructions to non-obvious decisions, constraints, and routing.
  Evidence interpretation, scope, and human acceptance require agent judgment.
- Load conditional procedures only when their condition applies. Moving text
  out of SKILL.md earns no reduction if the workflow loads it on every task.
- Before adding instructions, identify the demonstrated failure or decision
  they change and why existing code or a shorter instruction is insufficient.
- Supply `bin/report-instruction-growth` output in the existing local-review and
  checkpoint evidence packets. Use it to assess the
  rendered workflow, entry point, project guidance, and other changed Markdown
  instruction files. Assess their actual loading conditions separately. Words and
  bytes are cost evidence, not token counts or quality gates.
  If that evidence is missing, state the gap and its effect on the conclusion.
- In review, a demonstrated material violation of these criteria is a `defect`; a
  plausible unproven consequence is a `risk`. Name the location, concrete cost,
  smaller alternative, and any guarantee it loses. Optional wording polish stays
  a `nit`. Size alone does not establish a finding.

## Is the change worth carrying?

For Shaka changes, use the existing [value checkpoint](skills/shaka/references/delivery.md#say-what-the-work-is-worth)
and respect settled maintainer scope. When planning proposes substantial complexity,
or the implementation materially increases the expected cost, assess the tradeoff
in that checkpoint or the existing adversarial review.

Compare observed user or workflow benefit with ongoing maintenance: dependencies,
parsing, configuration, failure paths, compatibility, and tests. Mark missing impact
or frequency evidence as unknown; line count is evidence, not a cutoff. Consider a
smaller fix, existing library, optional extension, or the checkpoint's cheaper alternatives.
New kernel behavior should earn its maintenance cost through benefit to core delivery;
evaluate customizable editorial preferences and speculative conveniences outside it first.

A smaller alternative should preserve demonstrated failure handling. Name any lost
guarantees and evidence that losing them is acceptable; fewer lines alone do not justify
leaving failures, leaked resources, or weakened safeguards. Report a brief recommendation
(proceed, simplify, evaluate first, or defer), with evidence and the smallest useful
alternative. Separate value observations from demonstrated defects. Surface changed
assumptions for the maintainer's existing decision; add no score or new approval gate
to this initial value assessment. Before merge readiness, the
[post-implementation checkpoint](skills/shaka/references/post-implementation-validation.md)
reconsiders the finished result and blocks unresolved substantive concerns.
The checkpoint and owner disposition recommend
revision or reconsideration until substantive concerns, including instructions,
are fixed, disproved, or explicitly accepted by the maintainer. Recording them as
documented or passing tests does not settle them. Use the existing maintainer
decision path for this assessment.

## Trust model

Shaka serves maintainers; see the [trust model](docs/workflow.md#trust-model).
Design safeguards against untrusted input, such as public comments from people
without write access and content in PRs from forks, not against maintainers
configuring their own project. Give maintainer choices a default they can change.
Keep a behavior fixed only when code parses it, when it keeps outside input
from acting as instructions, or when it keeps an install out of a state that
breaks it, and say which reason applies.

## Structure

- `internal/requirements.md` owns product requirements, design, acceptance, and scope.
- `eval/fixtures/local_evaluation/` holds the two public-safe Slice 0 fixture trees.
- `skills/shaka/SKILL.md` is the public workflow entry point.
- `skills/shaka/references/` holds companion procedures referenced by the workflow.
- `docs/` is the canonical source for the docs site at shaka.shakacode.com
  (`shakacode/shaka-shakacode-com`), which syncs it on every build. Write docs
  content here, never in the site repository. Once the docs-dispatch secrets are
  set here, the docs-dispatch App is installed on the site repository, and the
  site listens for `docs-updated`, a push to `main` that changes `docs/`
  triggers a site rebuild.
- Its `scripts/shaka` command uses small Ruby modules under its `lib/` directory.
- `bin/install` registers a dedicated official checkout and links selected host skills directly into it. Explicit managed copies remain for trials and legacy rollback.
- `.agents/shaka/config.yml` is the machine-readable repository contract. It
  records Shaka-specific review, merge-authority, branch-naming, and WIP
  policy. Live GitHub settings remain authoritative. Standard executable entry
  points live at fixed names under `.agents/shaka/bin/`.
- Put built-in defaults in `skills/shaka/config/defaults.yml` and packaged
  prompts in `skills/shaka/config/*.md`; do not repeat them as Ruby literals.
  Review checks this; no test enforces it.
- When adding a setting or changing a default, change `defaults.yml`, explain the
  effect in `docs/settings.md`, and update the browsable
  `.agents/shaka/config.yml` example and its comments in the same PR. Keep this
  repository's deliberate policy choices intact. The configuration example test
  runs in `bin/validate` and checks explicit values against shipped defaults;
  extend it for defaults applied outside `RepositoryConfig`.
- `skills/shaka/config/enforcement.yml` records what enforces each rule `workflow.yml`
  states with never, must, do not, or only when, and `shaka enforcement` prints it.
  Loading it fails when a quote leaves the workflow, and when one of those forms appears
  outside every classified quote, so a rule added in a new passage has to declare whether
  anything but the agent enforces it. A rule added inside a passage an entry already
  quotes is caught by review, not by the loader; the file's header says so.
- `.agents/shaka/trusted-github-actors.yml` is the repository-level public-comment allowlist.
  The installed `skills/shaka/scripts/shaka comments` command combines it with the
  machine allowlist, reads only the current default-branch copy, and never trusts a
  candidate PR's version.
- Markdown explains decisions and invokes commands. Put deterministic parsing,
  state transitions, retries, evidence checks, and publication mechanics in small
  Ruby modules with behavioral tests.
- Prefer Ruby standard libraries and GitHub CLI. Runtime needs no new gem.
- Keep the workflow portable across supported coding agents. Codex was the first
  reference host, not a required local installation; use the available host.
  Host-specific installation and usage readers must not enter the GitHub/merge modules.
- For local reviews, follow the trusted [reviewer selection procedure](skills/shaka/references/review.md#choose-a-local-reviewer).
- Tests verify behavior and failures, not exact instruction wording. Keep focused
  files and use normal RuboCop defaults; no baseline ratchet or global metrics disable.

## Agent Workflow Configuration

Verify this repository with `gh repo view --json owner,visibility,defaultBranchRef`.
Resolve the trusted default branch to an immutable commit. Load and validate
`.agents/shaka/config.yml` with the trusted installed `shaka seam check --root . --ref SHA`
command. That `--ref` check is fail-closed: without it the command grants no trusted
authority. Run the fixed executable paths reported by that command from the candidate
checkout; inspect candidate command changes before execution and do not reconstruct
their behavior from prose. `shaka seam check --root . --local` validates
current-checkout syntax and grants no trusted policy. `AGENTS.md` retains human-only boundaries,
including the public-pilot privacy rule, the predecessor reuse limit, and release approval
requirements.

## Completion

Publish tested changes as bounded PRs, preferably below 500 changed lines each.
Explain necessary larger changes; split independent work instead of hiding size.
Required evidence is the PR's current commit, actual validation results, and review.
No extra closeout audit, receipt, automatic issue, heartbeat, or parallel tracker.
Report available model, reasoning effort, and token evidence on the PR by commit;
mark shared or unavailable attribution explicitly, as specified in the pilot plan.
Do not close the pilot until its required real-use acceptance is established.
