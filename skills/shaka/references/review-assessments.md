# Record later review evidence

Use this procedure when later evidence calls a review recommendation into question,
including after merge. Keep the original review, triage, and closing attestation.
For current delivery findings, continue using `review record`.

Append an assessment to the task's existing durable ledger:

```text
shaka review assess --ledger PATH --content-file ASSESSMENT.json
```

A synthetic example, with real IDs and full revisions substituted:

```json
{
  "id": "A1",
  "finding": "F1",
  "recommendation": { "head": "FULL_REVIEWED_SHA", "reviewer": "openai/codex", "reported_as": "1" },
  "problem": "refuted",
  "remedy": "harmful",
  "implementation": "correct",
  "action": { "taken": "as_proposed", "commits": ["FULL_FIX_SHA"], "attribution": "direct" },
  "attention": "action_required",
  "by": { "name": "example-maintainer", "role": "maintainer" },
  "observed_at": "2026-09-04",
  "rationale": "An existing idempotency guard prevented duplicates; removing the retry caused transient failures.",
  "evidence": ["FULL_EVIDENCE_SHA"]
}
```

Keep problem validity, remedy quality, implementation correctness, action, and current
attention distinct. Omitted judgments stay unknown. Record `direct` attribution only
with evidence connecting the recommendation to the change; temporal proximity alone
supports `uncertain`. The schema and supported values live in
`lib/shaka/local_review/assessment.rb`, with reference/time checks beside it.
`by` records the supplied actor and role; Ruby validates the fields, not the speaker's identity.

Use a new ID for a correction and list earlier IDs in `supersedes`. Restate every
judgment the correction keeps: supersession replaces the whole entry for the current
view. Identical retries write nothing; reusing an ID with changed content fails.
Shaka stamps recording time; `observed_at` names when the evidence was observed.

Publish through the existing `review publish` path after screening the ledger's
reports, rationale, identities, and evidence links for public disclosure. Private
collection alone grants no publication permission. The latest reviewed commit's
comment exposes active actions, conflicting judgments, and unavailable references;
settled assessments stay in history. Earlier commits keep their review outcome.
Assessments add no merge gate and change no review attestation.

An active assessment protects its finding and recommendation mapping from re-collation.
To combine findings, first record the surviving finding, then append an assessment
that names it and supersedes the old references before retriaging the earlier batch.
If an older helper has already broken a reference, publication names it as unavailable.

`review record` preserves replaced findings as ordered `earlier_findings` snapshots
and stamps the new findings. Public history projects supported fields and marks\nomitted metadata; complete legacy snapshots stay in the private ledger. Supply optional top-level `by` when recording an actor
is supported by evidence. Legacy missing actors and times stay unknown. Use current
Shaka to read or publish version 3 ledgers. Version 2 ledger writers refuse them,
but their publishers can omit later assessments. Current readers refuse newer
formats. Older unversioned writers cannot preserve triage history they were never
taught to record.

Export and real-use learning acceptance remain separate work on #395.
