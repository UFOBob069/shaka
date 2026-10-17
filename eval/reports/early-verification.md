# Early caller verification

Issue [#421](https://github.com/shakacode/shaka/issues/421) asks Shaka to learn from
poteto's verification practice. This change replaces the existing TDD paragraph
with caller-level reproduction before production edits and an explicit check of
the fix's safety assumption. It keeps the existing delivery gates.

The isolated comparison shows a useful difference in this fixture: the candidate
tested chunk boundaries before editing and preserved empty-chunk delivery. Both
arms already wrote a failing receiver test before editing. Earlier testing alone
is therefore a tie; broader effectiveness is unknown.

## Comparison

On October 17, 2026 UTC, four fresh subscription Codex CLI sessions used
`gpt-6.1-sol`, requested medium effort, a 180-second deadline each, and the
[same seed](../fixtures/early_verification/seed) and [tasks](../fixtures/early_verification/cases.json).
Observed routed model is UNKNOWN. Only the implementation paragraph differed;
this tests that instruction, not a whole-workflow rollout. No GitHub mutation or
metered provider was used.

Baseline is the implementation paragraph at `a5026372f4734ab77369068634f99d476a8d9ceb`;
candidate is this PR's replacement. Their SHA-256 hashes are respectively
`6ab4d852660187d57ab963585fd127bcd7164b700db5a4926f27c0aff15b9253` and
`29eacef39d646f367caef3aa18eb99057bd82f32200dbfd4d0d2f49b66d95f04`.
Prompts contained `Implementation guidance:`, that paragraph, `Task:`, and the
unchanged task. Neutral directories contained no project instructions. A temporary
Codex home retained subscription authentication without global instructions;
rules, user config and skill injection were disabled. Completed command traces
showed no global guidance or installed Shaka reads in these four runs. Candidate
listed parent-directory AGENTS.md paths but did not read their contents.

Criteria fixed before these sessions: reproduce through a real caller before the
first production edit, rerun the same check after the fix, exercise the shared
decoder's buffering assumption, and keep the typo control limited to its README.
The independent probe, developed after preliminary trials, was fixed before these
sessions and never included in their prompts. It tests all 595 two-cut partitions
of three records, asserting delivery after each of the three chunks, including
empty chunks. These are 1,785 assertions, not independent model trials.

| Observed action | Baseline | Candidate |
| --- | --- | --- |
| Real Receiver failure before production edit | Yes: event 5, two failures | Yes: event 6, one failure and an empty-chunk error |
| CLI before production edit | No | No; both exercised CLI after editing |
| First production edit | Event 7: remove early return | Event 8: remove early return and retain an empty string buffer |
| Rerun | Event 8: 4 tests, 13 assertions pass | Event 9: 4 tests, 1,795 assertions pass |
| Independent probe | Fails at cuts `[0,0]`: nil buffer | Passes all 1,785 assertions |
| Typo control | Only README changed; spelling checked | Only README changed; unified diff inspected |

Event numbers refer to native JSONL `item_N` IDs. The [selected native events](../fixtures/early_verification/outputs/events.jsonl)
retain command order, changed paths and captured output with host paths normalized.
Generated code and tests are retained as
[baseline](../fixtures/early_verification/outputs/baseline.patch) and
[candidate](../fixtures/early_verification/outputs/candidate.patch) patches.

| Run | Seconds | Input tokens | Cached within input | Output | Reasoning within output |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline behavior | 30.50 | 91,544 | 84,224 | 1,251 | 115 |
| Candidate behavior | 40.41 | 117,932 | 103,552 | 1,618 | 253 |
| Baseline typo | 12.44 | 58,273 | 55,040 | 343 | 0 |
| Candidate typo | 12.12 | 60,978 | 56,192 | 317 | 0 |

These are native completed-turn counters for these sessions only, excluding
implementation, reviews and qualification attempts. They establish no efficiency
benefit. Candidate behavior used more tokens and time.

## Reproduce the outcome

Copy the seed into two temporary directories. Apply the corresponding patch with
`patch -p1 < /absolute/path/to/outputs/ARM.patch`, then run from this checkout:

```sh
ruby eval/fixtures/early_verification/probe.rb /path/to/baseline-copy
ruby eval/fixtures/early_verification/probe.rb /path/to/candidate-copy
```

Expected exit statuses are 1 and 0. Run each generated suite with
`ruby -Itest -e 'Dir["./test/*_test.rb"].sort.each { |file| require file }'`.
To repeat the model comparison, use fresh seed copies and the prompt construction
above, holding model, effort, deadline and host context constant. Retain command
order and outputs; do not infer pre-edit verification from final tests alone.
The seed intentionally fails the independent probe; it is not production code.
Codex CLI was 0.163.0; behavior sessions used the same available Ruby 3.4.6.

## Qualification and limits

Preflight corrected an accidentally frozen initial buffer before any model run.
The first four sessions inherited global instructions, including installed Shaka.
Both behavior arms verified before editing; only candidate passed the later probe.
Two attempted isolation sessions were stopped when the intended flag was absent.
Another two completed with `project_doc_max_bytes=0` but still loaded global
instructions; both passed the probe. They are excluded from the isolated comparison,
not counted as a candidate advantage. No outcomes were
retried within the final four-session comparison. Qualification overhead and
these earlier outcomes remain separate from its usage figures.

The [first isolated pair and outputs](https://github.com/shakacode/shaka/tree/9f42ec4099c0e297703b5b5e2acce605771f9ad2/eval/fixtures/early_verification)
used the shorter paragraph at that commit: both arms tested Receiver before editing;
only candidate exercised the CLI before editing and passed the independent probe.
Review found that replacement dropped existing code-placement, browser-tool and
manual before/after directions. Restoring those constraints prompted this new
four-session comparison, with no outcome-based retries. Its baseline again failed
the empty-chunk probe and candidate passed; pre-edit CLI use did not repeat.
The earlier pair's report retains its separate native usage figures at that commit.

This synthetic streaming task gives concrete behavior evidence for one model and
one pair. The probe covers chunk boundaries, not malformed JSON or arbitrary
transport failures. Shared subscription execution, model variability and no
randomized repetitions limit causal attribution. Real Shaka delivery is untested.
The evidence supports trying this small instruction change; it does not prove
general compliance or justify a new runtime gate.

The rendered workflow grows by 54 words/382 UTF-8 bytes; entry point and AGENTS.md
are unchanged. The paragraph is rendered on every task, with its caller procedure
conditional on behavior changes. It adds no file load, setting or dependency.
The predecessor's `verify-pr-fix` practice informed the before/after check; no
legacy contracts or implementation were imported.
