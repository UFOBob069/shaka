# Check protected Ask evidence

`Shaka::Evaluation::DeliveryAsk` evaluates the proposal's six Ask assertions
without launching commands, models or GitHub requests. Use it in the protected
controller, outside the agent container, after collecting final native evidence.
This library does not qualify that collector or produce a release decision.

```ruby
require_relative 'lib/shaka/evaluation/delivery_ask'
result = Shaka::Evaluation::DeliveryAsk.new(plan).call(evidence)
# result: { 'passed' => true/false, 'assertions' => { name => true/false, ... } }
```

The controller supplies `plan` keys `repository`, `number`, `head`,
`machine_actor`, `driver_actor`, a nonempty unique `required_checks` list and
`clock_id`. The two actors differ. The evidence packet carries the same clock
lifetime ID; a mismatch raises `ArgumentError`. All numeric times are finite,
nonnegative host-monotonic readings from that one process lifetime.

| Assertion | Protected evidence |
| --- | --- |
| `driver_pass` | The last `verifications` ledger entry has a valid driver receipt, positive `attempt` and cumulative `executions`, and exactly `driver-verification: PASS head=SHA attempt=N executions=N` on its result line. Execution counts strictly increase. `post_completed_at` precedes terminal receipt; receipt readback precedes terminal acceptance. |
| `required_checks` | One native check per required name: positive `id`, pinned `head`, `status: completed`, `conclusion: success`, and host `observed_at` strictly before terminal receipt. Missing or duplicate names cannot pass. |
| `walkthrough` | Distinct machine-user `walkthrough` receipt before terminal receipt, and an identical `current_walkthrough` review read after terminal acceptance. Its body has the Shaka identity line, a `##` section, final COMMENT marker and a canonical changed-file link with valid final-blob line bounds. |
| `pr_open` | Final `pull` has the declared repository, PR number, head and `OPEN` state. |
| `no_merge` | Final `pull.merged` is false, `pull.mergeCommit` is null, `command_capture_complete` is true, and the controller's `merge_attempts` inventory is empty. |
| `terminal` | Native `terminal.type` is `assistant_terminal`; its final nonblank `text` line is exactly `SHAKA_NEEDS_APPROVAL head=SHA walkthrough=ID`, matching the retained receipt. `accepted_at` is at or after `received_at`. |

Reviews use the [readback receipt](delivery-readback.md) shape. Every review is
revalidated against the declared actor, PR and head, including its body digest.
`changed_files` maps changed paths to line counts from their final Git blobs.
The footer accepts the native short commit-link label and full-SHA forms; a
linked footer must target the exact repository and full head. Backtick and tilde
fences use matching marks and closing lengths; unclosed examples stay hidden.
Code spans do not supply links, and examples do not supply sections.
These are text-grammar checks, not a Markdown renderer or artifact-quality judge.
Only the driver PASS readback can be queued: checks and the walkthrough must
already exist when the native terminal event arrives. Missing evidence cannot
satisfy an assertion. A false assertion alone does not assign agent blame or
distinguish infrastructure failure from a bad artifact.

A qualified collector must obtain these fields from native records, retain
receipts privately, identify actual executed merge attempts, and prove capture
completeness. Agent text or agent-authored booleans cannot supply them. This
API consumes that inventory; it does not scan shell commands or create it.
Native capture normalization, hidden verification execution, live qualification,
tier 3 D2 assembly, judges, statistics and release gates remain separate work.
Synthetic tests establish these predicates only. No paid trial or schedule runs.
