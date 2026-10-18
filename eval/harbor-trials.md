# Launch budgeted Harbor trials

The eval-only `HarborTrial` Ruby API runs a prepared single-step tier 2 task inside a
`Runner` reservation. It supports the Codex and Claude Code subscriptions
accepted in ADR 0001. It does not schedule evaluations or decide release readiness.

The operator supplies the trusted controller, the prepared task directories, a
skill checkout, a selected subscription credential file, and a record-building
block. Keep these inputs and all captures outside the candidate workspace. The
task owns its isolation recipe: use the [qualified spike recipe](reports/harbor-spike.md),
including a non-root agent, read-only skill mounts, dropped capabilities, init,
resource limits, the ICMP restriction on both network sidecars, and a fresh
network-disabled verifier. This API does not qualify arbitrary task images or
Compose files. Docker must run on the Linux host qualified for Harbor's allowlist;
the spike found that Docker Desktop's kernel lacked the required nftables feature.

Construct `HarborRuntime` with absolute `tools` paths named `harbor`, `source`
and `docker`, plus `credential`, `skill` and a `profile`. The profile requires
`host`, `model`, an exact `version` for the host CLI, `reasoning_effort`, and
`timeout_seconds` between 1 and 3600. Before any reservation, preflight requires a
clean Harbor source checkout at `b53b8134e1241686dca7759af188f987ecc48e8b`
and Harbor 0.24.0. `PATH` must resolve the selected Docker executable so launch,
discovery and cleanup use the same client. `PYTHONPATH` selects that source and the
tested Codex upload adapter. The requested host version is not an attestation of
its observed version.

`HarborTrial.new(runtime:, usage:, tasks:, directory:)` takes a `NativeUsage`
instance, a map of task IDs to prepared directories, and a private capture
directory. Its `run(tasks, budget:, records:)` block receives task metadata,
reservation ID and a private capture. Use the same [durable budget](budget-runner.md)
for every paid caller. The approved pilot limits are $200/month including judges,
retries and manual tier 3, $5/night and $15/PR. This API accepts tier 2 only and
performs no retry. A single trial can exceed its remaining allowance; its full
known charge is retained and later calls stop.

The controller inherits only an explicit environment. It disables Harbor
telemetry and dotenv loading, starts in a disposable home, uses a private temp
directory, and supplies only the chosen
subscription. Codex requires subscription tokens and rejects an API-key-bearing
auth file; Claude uses forced OAuth. Credentials never enter the command line or
trial configuration. Controller files and credentials are removed on return;
native logs and result files remain under the private capture directory.

After the process exits or times out, the wrapper inspects reservation-owned
containers before deleting their Compose containers, networks and volumes. Image
IDs in the capture identify the actual agent and verifier containers. Cleanup
matches only the reservation's exact agent project or verifier project prefix.
A cleanup failure still attempts the other resource types and leaves the account
pending. After a controller crash or forced termination, inspect and remove that
reservation's resources and reconcile its charge before clearing pending state.

The capture contains Harbor's native result, image identities, normalized usage,
and a harness-error flag. Session collection includes descendant JSONL files and
rejects paths resolving outside the trial. The wrapper replaces the builder's
usage and rate-card hash with native-reader results. A nonzero exit, timeout,
missing or mismatched result, or native exception forces `HARNESS_ERROR` and an
unknown score even when Harbor exits zero. Known charges settle; missing usage
blocks later spending. Logs, native results, image project names and diagnostics
remain private. Only the closed run-record schema reaches the record store.

The trusted block still owns deterministic grading, artifact digests, timings and
the full D2 fingerprint. Keep unobserved fields `UNKNOWN`; a Harbor reward alone
does not establish a Shaka gate or a quality score. Complete fingerprint capture,
publication graders, calibrated judging, paired statistics and D9 release
decisions remain unbuilt. The lifecycle tests use disposable native subprocesses
and synthetic Docker responses; they make no model calls and do not requalify
the container recipe.
