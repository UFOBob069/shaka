# OpenRouter reviews and recorded charges

Load this reference only for `deepseek/openrouter` review execution or OpenRouter usage evidence.

## Review execution

Use `deepseek/openrouter` with the explicit `deepseek/deepseek-v4.1-flash` model.
Set `OPENROUTER_API_KEY` in the invoking process; Shaka never prints the key.
The existing trusted reviewer configuration can name this opt-in adapter; do not
change another user's configured reviewers automatically. The exact model and
supported efforts (`low`, `high`, `max`) were checked against
[OpenRouter's model metadata](https://openrouter.ai/api/v1/models) on 2026-10-07.
Use this optional reviewer alongside the existing reviewers. Start with `low`;
paid high-effort trials on a large diff returned both useful reports and incomplete
outcomes. Completion, review quality and savings are not guaranteed.

OpenRouter routes requests to upstream providers. The adapter leaves routing and
data policies to the account's settings; it does not enforce a provider allowlist
or zero data retention. Before sending private code, confirm that the account's
provider and privacy policies authorize every possible recipient.

```sh
shaka review run --root DIR --base BASE_SHA --head HEAD_SHA \
  --reviewer deepseek/openrouter --model deepseek/deepseek-v4.1-flash --effort low \
  --criteria-ref TRUSTED_SHA --settings-ref TRUSTED_SHA --repository OWNER/REPO \
  --ledger OUTSIDE_CHECKOUT.json
```

The request supplies the normal review prompt, diff, trusted criteria and prior
findings, with no tools. It cannot read unchanged source or run tests. Its report
must carry the existing exact-head closing attestation before the runner marks it
completed. `review record` and `review publish` use the existing ledger contract;
Ask still requires a maintainer's merge decision.

Each request has the selected review timeout and a 65,536-token completion cap.
Reasoning tokens count toward this cap. A high-effort review can exhaust it before
producing review text; that outcome remains incomplete and can still incur a charge.
Missing credentials return `credentials_missing` with `attempted: false`.
Malformed credentials return `credentials_invalid` before transport, without echoing the key.
Unsupported model or effort stops at setup. HTTP/API errors, network failures and
timeouts return `not_completed`; Shaka does not retry, switch models or treat
unsupported settings as provider unavailability. Response bodies and reasoning
are excluded from diagnostics and usage files. Review text remains in the report.

The result's `usage` path contains only aggregate API metadata. Include it in the
PR evidence table through:

```sh
shaka usage --host openrouter --file USAGE_PATH --all-turns \
  --commit HEAD_SHA --contribution review --format json
```

Copy the returned `record` into description `usage.records`. Record the report's
native model, token count and charged cost in the ledger's existing `usage` mapping
when available. Missing model, counters or cost stay UNKNOWN, including when a
review succeeds without usage. A malformed or truncated report can still incur a
charge; retain its usage too. The adapter is covered by deterministic request,
failure, report and accounting tests; that is not evidence of live model quality
or savings. Cloud hosts need explicitly provisioned credentials and HTTPS access.

## Recorded charges

Read the aggregate `usage` file returned by `shaka review run` using
`--host openrouter --file PATH --all-turns --contribution review`. Copy its JSON
`record` into the description's `usage.records` like other reviewer contributions.
API response IDs deduplicate copied files. No host transcript discovery is used.

OpenRouter's [usage accounting](https://openrouter.ai/docs/cookbook/administration/usage-accounting)
reports inclusive prompt tokens, completion tokens (including reasoning), optional
cache/reasoning subsets and `usage.cost`, the amount charged to the account in
USD-denominated OpenRouter credits. Shaka uses that reported charge, never
`upstream_inference_cost` or direct DeepSeek prices. It does not estimate Codex
plan credits for this request. Missing or malformed costs and counters stay
UNKNOWN; no counter or charge is inferred as zero. Report metadata contains no
prompt, candidate code, response text, reasoning or credentials.

[DeepSeek's direct API](https://www.deepseek.com/en/news/deepseek-v4-1-flash/)
uses `deepseek-flash` and has different peak/off-peak pricing. This integration
supports OpenRouter's explicit slug, not the direct API. Provider rates can
change; the recorded response charge is the accounting source.
