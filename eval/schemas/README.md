# Check a private run record

Ask your agent to validate a saved trial record against
[`run-record-v1.schema.json`](run-record-v1.schema.json). For example:

> Check my private trial record against the Shaka evaluation schema and explain any missing fields.

The offline command is:

```sh
eval/bin/shaka-eval check-record /private/results/trial.json
```

Exit 0 means the record has the required shape and matching task-bank identities.
Exit 1 means invalid JSON, an unreadable file, or a contract violation. Exit 2
means incorrect command arguments. Output contains `valid` and `errors`; it never
echoes record values, unknown property names, or the input file path.

This is the first prerequisite in [ADR 0001](../../internal/adr/0001-eval-and-release-gating.md#documentation-to-write-first).
It does not collect fingerprints, execute tasks, verify their claims, compare
runs, or declare a release clean. A structurally valid record can be provisional.

Version 1 contains every D1 section and D2 fingerprint field. Content digests use
`sha256:` followed by 64 lowercase hexadecimal digits; Git revisions use full
40- or 64-digit IDs. A task-bank identity can also be a content digest.
`UNKNOWN` means unavailable evidence; `N/A` means the field does not apply.
Neither is a missing key, an empty string, or zero. Applicability and comparison
eligibility belong to the later fingerprint/comparison checks.

Usage is normalized per model: `input_tokens` includes cached reads and writes;
those counters are subsets. `output_tokens` includes `reasoning_tokens`.
Unknown counters and dollar estimates remain `UNKNOWN`. Times are seconds.
The `judge` array preserves rubric and both pairwise call orders, with the facts
supplied by Ruby. The contract records scores and facts; it does not grade them.

Run records, machine identities, transcripts, and artifact paths stay private.
An artifact may carry its digest without a local path; that does not authorize
publishing the run record. The test fixture is entirely synthetic.

The schema uses [JSON Schema 2020-12](https://json-schema.org/draft/2020-12/json-schema-validation).
Its Ruby checker supports only the keywords used here and local `$defs`
references. An unsupported keyword in any branch stops schema loading. The
checker needs Ruby standard libraries and stays outside the product runtime.
