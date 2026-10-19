# Checkpoint verification against blast radius, #421

Issue [#421](https://github.com/shakacode/shaka/issues/421)'s
[order of work](https://github.com/shakacode/shaka/issues/421#issuecomment-6205960445)
asks whether the checkpoint sentence added by [#547](https://github.com/shakacode/shaka/pull/547)
and [#549](https://github.com/shakacode/shaka/pull/549) changes what the reviewer
reports. The reviewer is asked whether verification is proportionate to what a failure
would reach and whether a revert undoes it, and to name paths nobody exercised.

The sentence changed behavior in a consistent direction. With it, every run named the
paths the PR left unexercised and said whether a revert undoes the damage. Without it,
no run did either. On the merge-path PR, all three runs with this repository's prompt
moved from Proceed to Simplify/reframe because nobody had tested the agent's new
consent decision. On the docs edit every run still said Proceed with no concerns, and
reports grew by 14 to 16 percent. The sentence has a cost. On the shared-caller PR, two
of five runs with it said Proceed and missed a real outcome gap that every run without
it found.

## What ran

On October 19, 2026 UTC the installed helper (`shakacode/shaka` at
`f9fbdb0bcc03641a9f8415dcc2fb00611232fd0d`) ran
`shaka post-implementation run` 30 times with `openai/codex`, `gpt-6.1-sol`, medium
effort, the configured reviewer for this repository's checkpoint. Codex CLI was 0.163.0.
Each run used the real runner, a detached checkout at the PR's squash commit, the
squash parent as base, and the same packet for both arms. Observed routed model is
UNKNOWN. No GitHub mutation happened.

`--ref` named a local, unpushed commit on top of `main` at
`2363e217b6034b4b684ef88f2a29ddda458d870f` that added the [four prompt files](../fixtures/checkpoint_blast_radius/prompts).
Both arms therefore read the same AGENTS.md criteria and settings and differed only by
`--prompt-file`. Each "before" file is the current prompt with the #547 or #549
sentence removed, so later edits such as #592 appear in both arms. Outputs record the
prompt as `eval-arms/NAME.md` in that local commit; the committed `prompts/NAME.md`
files are byte-identical, with the hashes below.

| Prompt | Arm | SHA-256 |
| --- | --- | --- |
| This repository's `product-checkpoint.md` (#549) | before | `8a99cfdc711940e9d7ed2ff0834bb6cfe525da96f9742d1260e979fac648b5ac` |
| | after | `7a5122b747cdbfb4eb619941ca165d0716652514af3178e2333c8cc8b073b17d` |
| Built-in `post-implementation-prompt.md` (#547) | before | `d4483d911e4108eb7c3b042a1e2b52dc5e1570c131e01ec13e04afe3d85c42b1` |
| | after | `ba7317c5cf3e83047c52c67838f4527573cc5ebe0ead7448f02353e19031ecfb` |

This repository's prompt ran three times per case and arm; the built-in prompt, which
other repositories get, ran twice.

### Fixtures

These are three merged Shaka PRs, not invented examples. Each
[packet](../fixtures/checkpoint_blast_radius/packets) restates that PR's published
description: its problem, scope, safety claim, verification and not-verified line.
Nothing was added to plant an omission.

| Case | PR | Squash commit | Why it fits |
| --- | --- | --- | --- |
| Bug in a shared caller | [#695](https://github.com/shakacode/shaka/pull/695) | `4b382e53` | `github/check_list.rb` feeds `pr`, `pr watch`, `handoff` and `merge`. |
| Irreversible external side effect | [#552](https://github.com/shakacode/shaka/pull/552) | `b7ee4555` | Lets `shaka merge` submit with no required checks; reverting Shaka cannot undo a merge. |
| Trivial edit | [#635](https://github.com/shakacode/shaka/pull/635) | `4aad9844` | Two Markdown tagline lines. |

### Scoring

[Criteria](../fixtures/checkpoint_blast_radius/criteria.md) were written before the batch ran. Reports were then shuffled under random IDs
and scored without the arm visible. The [key](../fixtures/checkpoint_blast_radius/blind_key.json),
[scores](../fixtures/checkpoint_blast_radius/scores.json) and every
[report](../fixtures/checkpoint_blast_radius/outputs) are kept. One person designed the
criteria and scored the reports, so the blinding reduces bias but does not remove it.
Columns marked "found" were added after reading, because the reviewers raised them
without being asked.

## Results

Counts are runs meeting the criterion, out of the runs in that cell.

### Bug in a shared caller (#695)

| Criterion | Repo before | Repo after | Built-in before | Built-in after |
| --- | ---: | ---: | ---: | ---: |
| States the fact safety rests on (only an already-failing path changes) | 0/3 | 3/3 | 0/2 | 0/2 |
| Names the consuming commands a failure reaches | 3/3 | 3/3 | 2/2 | 2/2 |
| Names a consuming path as not exercised | 0/3 | 3/3 | 0/2 | 2/2 |
| Says what a revert does | 0/3 | 3/3 | 0/2 | 2/2 |
| Found: HTTP status never reaches users | 3/3 | 1/3 | 2/2 | 2/2 |
| Conclusion Proceed | 0/3 | 2/3 | 0/2 | 0/2 |

The "found" row is a real gap in the merged PR. #695's summary says users "now see the
real error and its 403 status". The status is kept only in `Error#http_status`. The CLI
prints `e.message`, which is `gh pr N failed (exit 1).`, and `status.rb` stores only the
generic message. The PR's own test asserts that message
([`test/github_unprotected_check_list_test.rb`](../../test/github_unprotected_check_list_test.rb)).
Issue #656's acceptance, an error carrying its status, is met. The user-visible promise
is not. Every run without the sentence raised this as a concern. Two runs with the
repository prompt instead wrote a verification-proportionality paragraph and concluded
Proceed. So did the real
[#695 checkpoint](https://github.com/shakacode/shaka/pull/695#issuecomment-6257318842),
which used the "after" prompt. With n=3 this may be noise, but it is the one observed
cost.

### Irreversible external side effect (#552)

| Criterion | Repo before | Repo after | Built-in before | Built-in after |
| --- | ---: | ---: | ---: | ---: |
| States the fact safety rests on (exact head, empty check set only) | 3/3 | 3/3 | 2/2 | 2/2 |
| Says a revert cannot undo a wrong merge | 0/3 | 3/3 | 0/2 | 2/2 |
| Says no live GitHub path ran, only a fake client | 0/3 | 3/3 | 0/2 | 2/2 |
| Found: agent's consent decision for the flag is untested | 0/3 | 3/3 | 0/2 | 2/2 |
| Conclusion Simplify/reframe | 0/3 | 3/3 | 0/2 | 0/2 |

Every "after" run noticed that Ruby checks the head but the agent decides when to pass
`--empty-checks-confirmed-head`, and that nothing reported tested that decision. Two cited [the earlier unauthorized Ask merge](ask-merge-authorization.md),
and a third noted that the existing replay predates the flag. The three runs with this
repository's prompt asked for a non-mutating decision replay covering approved Ask,
unapproved Ask, Auto and a changed head, rather than a live merge. That is the evidence a maintainer
would want before an irreversible action. Runs without the sentence spent the space on
the missing instruction-growth report. The real
[#552 checkpoint](https://github.com/shakacode/shaka/pull/552#issuecomment-6205306738)
ran before #547 merged and concluded Proceed with no concerns.

### Trivial edit (#635)

| Criterion | Repo before | Repo after | Built-in before | Built-in after |
| --- | ---: | ---: | ---: | ---: |
| Proceed with no concerns | 3/3 | 3/3 | 2/2 | 2/2 |
| Asks for no extra verification | 3/3 | 3/3 | 2/2 | 2/2 |
| Notes the rendered page was not checked | 0/3 | 3/3 | 0/2 | 2/2 |
| Mean words in summary, reasons, concerns, alternative and next action | 130 | 151 | 97 | 111 |

The docs edit stayed brief and unblocked. The added sentence about the rendered page
not being checked is accurate but does not change the decision. Growth stayed within
the 25 percent bound fixed beforehand (+16 and +14 percent).

### Cost

| Arm | Runs | Mean seconds | Mean input tokens | Mean output tokens | Mean API-equivalent USD |
| --- | ---: | ---: | ---: | ---: | ---: |
| Repo before | 9 | 41 | 106,939 | 966 | 0.0588 |
| Repo after | 9 | 37 | 85,243 | 972 | 0.0603 |
| Built-in before | 6 | 36 | 99,458 | 952 | 0.0597 |
| Built-in after | 6 | 35 | 106,279 | 1,088 | 0.0579 |

The 30 runs cost $1.78 API-equivalent on a subscription. Token differences reflect how
much source each run chose to read, not the prompt length. Reports on the merge-path PR
grew by about 40 percent with this repository's prompt, because they now carry a
concern.

## What this does and does not show

This evaluates the checkpoint reviewer, the only thing #547 and #549 change. A
checkpoint cannot gather evidence. It can only judge the evidence it is given and name
what is missing. The implementing agent's side, reproducing through the real caller and
stating `safe_because` and `root_cause`, shipped later in
[#576](https://github.com/shakacode/shaka/pull/576), [#553](https://github.com/shakacode/shaka/pull/553)
and [#633](https://github.com/shakacode/shaka/pull/633). [The early caller verification replay](early-verification.md)
covers it. Nothing here shows whether agents now get evidence on the affected path, only
whether the checkpoint notices when they did not.

Limits: one model, one effort, three PRs, two or three runs per cell, and one scorer.
Packets were rebuilt from published descriptions, not the original packets, which are
not retained. The real #695 and #552 checkpoints are single observations under
different packets. No run used a non-Shaka repository.

## Recommendation

**Keep #547 and #549.** The sentence reliably makes the checkpoint name unexercised
paths and revert limits, and it caught a real, unexercised consent decision on an
irreversible merge path. It did not burden the docs edit. Watch for the observed cost:
on a reversible change, the reviewer may treat proportionate verification as enough and
miss whether the change delivers what its summary promises.

**Of the description slice, the Intent block and the verification list with a
not-verified line already shipped in [#553](https://github.com/shakacode/shaka/pull/553).**
Delivery guidance also already treats provenance and usage as collapsed audit material.
What remains is a fixed verification table, with claim, run path and a result value
from `passed`, `failed`, `not verified` or `inconclusive`. **Defer it.** In both cases
where the reviewer found something, the problem was a summary or safety claim that no
listed check covered. A Ruby-enforced row shape cannot detect that, because the agent
chooses which claims to list. #695's description already had well-formed checks and a
not-verified line. Its overclaim sat in the summary. The cheaper next step is to give
the checkpoint the description's intent and summary, so it can compare each promise
with the evidence. Revisit the fixed table if that comparison still misses claims.

A follow-up worth filing: #695's summary promises a visible HTTP status that no caller
prints. Either surface the status in the check-lookup message, or correct the claim.
