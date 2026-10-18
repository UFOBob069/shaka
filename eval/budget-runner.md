# Apply the pilot caps to a batch

The Ruby batch core checks the approved caps before each executor call and saves
its trial record privately before settling the charge. Ask your agent:

> Integrate my native trial driver with the budgeted batch runner. Keep the approved pilot limits and save records privately.

This is an integration API under `eval/lib/shaka/evaluation/`, outside the product
runtime. [Harbor execution](harbor-trials.md) and [native usage conversion](native-usage.md)
are available as integration APIs. Complete fingerprint capture and the `run` and
`nightly` commands remain unbuilt. A completed batch is not a quality
verdict or evidence that a release is clean.

The operator supplies `limits` explicitly; omitting them rejects the call.
[ADR 0001](../internal/adr/0001-eval-and-release-gating.md#budget) records the
approved pilot amounts. Pass a lower `cap` for a particular run; a request above
its supplied maximum is rejected. No delivery setting or built-in budget default
is added.

All batches use one private budget directory. A separate directory starts a
separate account and cannot enforce the shared cap. Judges, retries, and tier 3
must use that same account. Nightly scopes use the UTC date when the budget object
is created; charges enter the UTC month when reserved. A PR scope is its stable
PR identifier and retains its cap across months. Monthly accounting resets with
the calendar month, while unresolved calls continue to block execution.

The adapter boundary is:

```ruby
approved_limits = { 'monthly' => 200, 'nightly' => 5, 'pr' => 15 }
budget = Shaka::Evaluation::Budget.new(directory: private_budget_directory,
  limits: approved_limits, kind: 'pr', scope: '578', cap: 10)
runner = Shaka::Evaluation::Runner.new(budget: budget, directory: private_records_directory)
summary = runner.run(tasks) { |task, trial_id| native_driver.call(task, trial_id) }
```

The trusted driver returns a [version 1 run record](schemas/README.md) with the
assigned trial ID and unchanged task identity. It obtains usage from native
evidence, including failed calls, rather than from the agent's answer. A
`HARNESS_ERROR` record with known usage is saved and charged before the batch
stops. Tier 3 requires a `manual` budget with an explicit cap; it cannot run as
part of a nightly or PR batch in this increment.

Calls run serially across the account. A process reserves a call under an exclusive
file lock before invoking its driver. Unknown usage, an executor exception, a
record-binding error, or a storage failure leaves the reservation unresolved.
No later call starts until the operator reconciles it using actual native
evidence. `Budget#settle` accepts its ID, known dollars, and saved-record digest;
it refuses a repeated settlement or a different scope. There is no automatic
retry or reservation expiry.

The append-only `budget.jsonl` and UUID-named record files use mode 0600. Writes
are flushed and synced before execution or settlement proceeds. A truncated or
invalid ledger stops execution; it is never silently reset. The aggregate summary
omits record contents, paths, and private exception messages. An unaccounted call
reports `UNKNOWN` dollars.

The limits stop new calls; an in-flight call can cross a cap, as ADR D9 permits.
Its full cost remains charged and the batch is partial. Exact decimal arithmetic
keeps rounding from admitting another call. A partial or harness-error batch
cannot establish complete release evidence; the release gate itself remains
unbuilt.
