# Check whether two run sets can be compared

Before attributing a score change to a skill or setting, ask your agent:

> Check whether these private baseline and candidate run sets are comparable on the skill axis. Report missing evidence and unrelated differences.

The offline command accepts two JSON arrays of [version 1 records](schemas/README.md):

```sh
eval/bin/shaka-eval check-comparison PRIVATE_BASELINE.json PRIVATE_CANDIDATE.json --axis skill
```

It returns `eligible`, `provisional`, or `refused`. Only `eligible` exits zero.
This checks fingerprint attribution; it does not score quality, calculate confidence,
or declare a release clean. The `diff`, `run`, and release-gate commands remain unbuilt.

[ADR D2](../internal/adr/0001-eval-and-release-gating.md#d2-a-fingerprint-on-every-run-and-a-diff-only-across-matching-fingerprints)
defines the `skill`, `model`, `provider`, `effort`, and `tier` axes. Only those
fields may differ between arms. A tier comparison may change the model's rate
card entry; both arms still need the same full rate card hash. A provider
comparison with different served models is refused and suggests the tier axis.

Each arm must contain the same tasks, task metadata, and trial count per task.
Trial IDs must be unique across both arms. Repeated trials within a task need
stable fingerprints, including the axis fields. The package, host, model, effort,
machine, runner, rate card, and bank must also stay stable across tasks in each arm.
Task-specific resources, judges, and fixtures may vary between tasks but must match
between the two arms for that task. Identical packages are allowed for baseline calibration.

`UNKNOWN` anywhere in a fingerprint, including nested evidence, makes the result
provisional. Required package, host, model, effort, machine, runner, and bank identity
cannot use `N/A` to become eligible. Other `N/A` values retain the record schema's
meaning: the field does not apply. The checker relies on the trusted record producer
to establish that applicability and the truth of captured values.

Output names fields and fixed reason codes. It omits task IDs, model values,
machine aliases, paths, record contents, and nested keys. Keep the input files private.
