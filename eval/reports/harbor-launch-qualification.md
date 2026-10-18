# Qualify the merged Harbor controller on Linux

Date: 2026-10-18 UTC. This qualifies one execution recipe through the merged
`HarborTrial` API; it measures neither skill improvement nor release readiness.

The controller from [PR #621](https://github.com/shakacode/shaka/pull/621), merged
at `642198c7349d6c5d2c95ef9f18e6e76b050af539`, ran the existing public-safe Ask/Go
qualification task with the accepted spike skill export. Harbor stayed pinned to
0.24.0 at `b53b8134e1241686dca7759af188f987ecc48e8b`, with the tested upload
adapter and both sidecars' ICMP restriction. Telemetry was disabled; no Hub upload
ran. The model used the existing Codex subscription.

The Ruby 3.4.6 controller used an explicitly selected Docker client and the
dedicated Linux daemon, without changing the global Docker context. A no-model
probe checked Compose, image identities, read-only bind resolution and the actual
Codex CLI version before reserving. The daemon reported Linux 7.0.0-28-generic and
Docker 29.9.1. Native session metadata also reported Codex 0.163.0.

## Result and budget

One completed trial passed the fresh separate verifier, with configured
`gpt-6.1-sol` and medium effort. Native usage reported:

| Measurement | Total |
| --- | ---: |
| Input tokens, including cached reads | 118,345 |
| Cached input tokens | 102,784 |
| Output tokens, including reasoning | 540 |
| Reasoning tokens | 74 |
| Cache-neutral API-equivalent dollars | $0.2420905 |
| Rate-card dollars with cache pricing | $0.0468 |

The latter is an estimate, not a subscription invoice. Routed model remains
`UNKNOWN`. The shared durable pilot account settled the charge and has zero
pending reservations. Its trial allowance was $5, below the $15 PR maximum and
$200 monthly maximum. Judges, retries and manual tier 3 share that monthly account;
no recurring paid schedule was enabled.

## Authentication recovery and cleanup

The first attempt failed subscription routing with HTTP 401 before generation.
It produced no model response, successful turn, or usage event. The runner retained
the failure and blocked further execution with a pending reservation. The operator
saved a reconciliation record and settled zero from that native pre-generation
failure evidence, rather than treating absent usage as zero automatically.

The [documented Codex account refresh](https://learn.chatgpt.com/docs/app-server#1-check-auth-state)
obtained a fresh access token without starting a model turn. One retry used that
token and its actual refresh timestamp; no long-lived refresh token was forwarded.
The retry passed and settled through the normal native usage reader.

Both attempts retained private readbacks of the four agent/verifier/sidecar
containers, then removed their owned containers, networks and volumes. The original
daemon resource baseline was restored. Disposable controllers and credential
copies were removed and the dedicated VM was stopped. Raw captures, transcripts,
records, image identities and the budget ledger remain private.

## Limits and next work

This is one successful Codex/Linux execution, not a matched comparison, a core-bank
task admission, or qualification of the Claude profile or arbitrary task recipes.
Its incomplete D2 fingerprint stays provisional. The readbacks motivate capturing
all container roles and controls in the next fingerprint increment. Remaining D2
fields, artifact graders, calibrated judging, statistics and D9 release decisions
still need implementation.
