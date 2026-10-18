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
an environment manifest and a harness-error flag. The manifest identifies each
retained agent, verifier and sidecar by Compose role and service, actual image ID,
container user, CPU/memory limits, init, capability and security options, process
limit, sysctls, tmpfs options and mount destinations/write access. Generated IDs,
host mount sources and environment variables are omitted. Ordering does not affect
its SHA-256 digest. Verifier project truncation can add a reservation-dependent
hash; the manifest normalizes one verifier group to the verifier role. Multiple
verifier groups, missing required readbacks, duplicate services, or no agent or
separate verifier main container leave the manifest and digest `UNKNOWN`.

The wrapper replaces the builder's `execution_framework` with the pinned Harbor
version and this `environment_digest`. The digest covers retained container
readbacks; it does not attest network rules, task contents, host kernel, or every
earlier runtime state. Task qualification still establishes isolation. Keep the
manifest private. A changed digest refuses every comparison axis; an old Harbor
record without a known digest remains structurally valid but provisional.

Session collection includes descendant JSONL files and
rejects paths resolving outside the trial. The wrapper replaces the builder's
usage and rate-card hash with native-reader results. A nonzero exit, timeout,
missing or mismatched result, or native exception forces `HARNESS_ERROR` and an
unknown score even when Harbor exits zero. Known charges settle; missing usage
blocks later spending. Logs, native results, image project names and diagnostics
remain private. Only the closed run-record schema reaches the record store.

The wrapper replaces the builder's entire fingerprint. It reads the host CLI
version from native session metadata, model identity and effort from normalized
usage, agent image and limits from the environment manifest, and Ruby and the
lockfile hash from the runner. Requested CLI pins never fill missing observations;
conflicting native identities become `UNKNOWN`. Codex does not report its routed
model. When usage omits configured model or effort, the retained Harbor lock can
supply those launch settings; it never supplies a routed model or observed CLI
version. Task-bank identity comes from the validated task metadata. Actions and
hosted reviewers are `N/A` for this tier 2 API.

Package capture requires a self-contained skill tree with all loaded guides and
helpers inside it. Symlinks leave package identity unknown. The reader hashes
every file, including hidden files, and file/directory permissions and ownership.
It reads Git commit and
modified state, and hashes workflow/enforcement files separately. An archive can
supply content but has unknown Git identity. Capture must match before and after
launch, and Harbor's single-skill lock must match the source and content digest.
These checks do not attest every intermediate filesystem state or discover
dependencies loaded outside the supplied tree; qualify the package accordingly.

Supply optional `fingerprints: {task_id => evidence}` to `HarborTrial.new` for the
private machine alias, fixture Ruby/version-lockfile hash, local reviewer CLI
versions, judge model/prompt hash and criteria-set hash. The accepted keys are the
corresponding [run-record fields](schemas/README.md). Obtain them from the actual
fixture, reviewer executions and judge configuration; use `N/A` only when the
field cannot apply. Omitted values stay `UNKNOWN`. Invalid fields are rejected
before preflight or a budget reservation. Builder guesses cannot override capture.
Without an explicit machine alias, the wrapper reads `SHAKA_MACHINE_ALIAS`.

The trusted block still owns deterministic grading, artifact digests and timings.
A Harbor reward alone does not establish a Shaka gate or a quality score.
Publication graders, calibrated judging, paired statistics and D9 release
decisions remain unbuilt. The lifecycle tests use disposable native subprocesses
and synthetic Docker responses; they make no model calls and do not requalify
the container recipe.

The [merged-controller Linux qualification](reports/harbor-launch-qualification.md)
passed one Codex trial under the pilot caps. Its authentication recovery and
accounting limits are recorded there; it does not qualify the Claude profile or
arbitrary tasks.
