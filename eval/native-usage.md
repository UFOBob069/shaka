# Account for collected Harbor sessions

`Shaka::Evaluation::NativeUsage` converts dedicated Codex or Claude Code JSONL
sessions into the run record's usage section. It calls an explicitly selected
installed `shaka usage` executable; it imports no product modules. It is the
accounting adapter for the Harbor runner, not a Harbor launcher.

Pass every native session belonging to one trial, including resumed sessions and
any tool-model sessions. The caller must collect these logs from the host and bind
them to the trial; agent-written token totals and Harbor's `cost_usd` are not inputs.
A partial collection cannot establish the full charge. The adapter checks the
supplied files; it cannot discover a session the collector omitted.

```ruby
require_relative 'lib/shaka/evaluation/native_usage'

usage = Shaka::Evaluation::NativeUsage.new(
  helper: '/trusted/installed/shaka/scripts/shaka',
  rate_root: '/trusted/rate-card-checkout'
)

runner.run(tasks) do |task, trial_id|
  # The trusted driver starts the trial, collects all native logs, and grades it.
  record, native_files = driver.call(task, trial_id)
  record['fingerprint']['rate_card_hash'] = usage.rate_card_hash
  record['usage'] = usage.read(host: 'codex', files: native_files)
  record
end
```

Use one [budget account](budget-runner.md) with the approved pilot limits across
generators, judges, retries and manual tier 3. The adapter launches no model calls.
An unreadable source, unsupported JSON shape, failed reader or unpriced response
leaves dollars `UNKNOWN`. The runner then leaves its reservation unresolved and
stops later calls. An aggregate Claude print-result JSON is unsupported: collect
the native JSONL sessions, as the pinned Harbor integration does.
An unsupported host or missing session list raises `ArgumentError` for the caller
to fix, before any source is read.

The rate card is captured at construction, hashed, and copied into a private
temporary checkout for each read. Original and cache-neutral input snapshots come
from the same source bytes. The installed reader sees the original counters first.
For repricing, a second copy assigns all input to uncached input, preserving each
response's model, context size, speed, geography, server-tool fees and output.
Provider pricing stays in the installed command. No rates are copied into eval.
Both reads must cover every distinct paid-response ID found in the source and
the same nonempty response set; neither price may be partial. An unidentified or
dropped response makes cost unknown. The installed reader deduplicates copies.

Reported tokens always come from the original read. Input includes cached reads
and writes, including Claude's separately reported counters; output includes
reasoning. Missing categories and identities remain `UNKNOWN`. A missing routed
model is not inferred from a configured model, so a costed run can remain
provisional for comparison. The reader's display-only fast suffix is removed from
the routed model; its price still uses fast mode.

The installed CLI rounds each cost column to six decimal places. Cache-neutral
dollars include a conservative half-microdollar allowance per column to avoid
undercharging that rounding. Billed dollars are the original rate-card estimate,
not an invoice or a subscription charge. Both are API-equivalent estimates.

Snapshots have mode `0600` inside a `0700` temporary directory and are removed even
on failure. The returned usage contains no session IDs, source paths, transcript
text, reader diagnostics or report notes. Store it in the private trial record.
Full fingerprint capture, pinned Harbor launching, deterministic artifact graders,
judging, paired statistics and release verdicts remain subsequent integration work.
