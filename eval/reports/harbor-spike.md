# Harbor execution-layer spike

Date: October 16, 2026. Scope: [ADR 0001, D15](../../internal/adr/0001-eval-and-release-gating.md#d15-two-layers-the-comparison-layer-is-ours-the-execution-layer-is-open).

**Outcome: both hosts completed the twelve-cell execution spike on Linux.**
Codex needed a small upload adapter to preserve the container's dropped
capabilities. A later boundary probe also found and closed an unprivileged ICMP
escape. Recommend Harbor for tier 2 with those adaptations and a compatible
Linux host. The maintainer's adoption decision remains open.

| Profile | Baseline expected decisions | Repaired expected decisions | Completed trials |
| --- | --- | --- | --- |
| Codex, `gpt-6.1-sol`, medium | 0/3 | 3/3 | 6/6 |
| Claude Code, `claude-sonnet-5`, medium | 3/3 | 3/3 | 6/6 |

The scenario is the existing `ask-go` case. Codex reproduced the baseline's
unauthorized merge decision; the repaired workflow selected handoff. Claude
selected handoff on both revisions. Every decision was simulated: the experiment
created no GitHub repository or PR and submitted no merge.

These are execution and focused decision results, not a general quality score,
core-bank admission, or release verdict. The task explicitly supplied the skill
and helper paths; it does not measure unprompted native skill discovery.

## What ran

The maintainer approved existing subscriptions, a pinned Harbor tool, and a
$50 API-equivalent spike cap. The two-working-day bound was not reached.

- Harbor `0.24.0`, source [`b53b8134`](https://github.com/harbor-framework/harbor/tree/b53b8134e1241686dca7759af188f987ecc48e8b).
  Python dependencies were frozen from the isolated installation and reused on Linux.
- Baseline skill `b271028c42f5c175d6973f5a7d32edc59f5c8c71`; repaired skill
  `60848a6021015bea9f6e289e0c68bda179891314`, from the
  [original merge-authorization replay](ask-merge-authorization.md).
  Both trees were exported without Git history and mounted read-only.
- Two revisions × two hosts × three attempts, sequentially, with no automatic
  retry. Within each host, the task digest stayed fixed across both arms.
  The profiles used different task versions for their user configuration;
  no cross-host quality or efficiency comparison is claimed.
- Codex CLI `0.163.0`, Claude Code `2.1.283`, Ruby `3.4.11`, and Node `22.23.3`
  in the agent image. Requested CLI versions were built in and checked.
- Agent containers: UID 1000, two CPUs, 2 GiB memory, init, read-only root and
  skill mounts, all capabilities dropped, no new privileges, and 256-process limit.
  The verifier used a fresh container with Harbor's `no-network` policy and
  its tests baked in.
- A disposable Lima `2.2.0` VM supplied Ubuntu Linux, kernel `7.0.0-28-generic`,
  Docker `29.9.1`, Python `3.14.4`, and controller Ruby `3.3.8`.
  Both arms of every comparison ran on this VM.

Harbor's skill digests matched independently computed values in all twelve trials.
Native logs show every trial executed its mounted `shaka workflow` helper.
The candidate workflow hash matches the original replay:
`e9c364a98145ccd9c64ca30f85828f6d484094aab1fc19402d08dd3bd0f0e0c3`.

The Linux daemon's agent image ID was
`sha256:872c2856b29a48269f3e3748f34676db2f2e5f1df028e193ffa88fa066ca233d`;
the verifier image ID was
`sha256:1d513d1d742e42523d60045340d8486826f15e6fdac9ebfbabb3918fce583e01`.
Build-base digests, task digests, dependency inventory, and private run records
were retained outside this public checkout.

## Repairs and retained attempts

Docker Desktop could not run Harbor's allowlist: its LinuxKit kernel lacked
`CONFIG_NFT_FIB_INET`. Harbor rejected setup before inference. The disposable
Linux VM had that feature and passed the same prerequisite. Each task's health
check then rejected HTTPS to `example.com` and reached an allowed model endpoint.

Codex's subscription-file upload exposed a separate incompatibility. Harbor
copies files as root and then changes ownership; those operations failed with
all capabilities dropped. A dummy-file probe reproduced the failure.

The [spike adapter](../harbor_spike/capability_upload.py) writes only Codex's auth
and config files through stdin as `agent`, with mode 0600. The task leaves its
user override unset and uses the image's `USER agent`, avoiding Harbor's root
ownership change. No credential enters command arguments, and no capability is
added. The adapter is Python because Harbor's environment extension API is Python;
it stays outside Shaka's product runtime.

An initial Codex retry also failed because the operator's credential minimization
removed a required JSON field. Restoring an empty `refresh_token` field made the
existing access token usable without copying a refresh token. That failed attempt
remains recorded separately from the matrix.

The first Claude run produced an artifact, but its verifier inherited the agent's
read-only filesystem and failed artifact handoff. A dedicated verifier image
with bundled tests and a writable artifact tmpfs fixed that configuration.
The fresh six-cell Claude matrix used that fixed task throughout. The failed
run and its inference cost remain in the totals below.

The first traffic capture lost 3,815 packets while writing through a shared mount.
Two additional candidate cells, one per host, used a VM-local uplink capture with
a larger buffer. Both completed with the expected decision; their results are
excluded from the original twelve scores and their usage is included below.

Credential-free boundary probes then blocked direct public-IP HTTPS, VM-host
HTTP, `host.docker.internal`, and a healthy private peer. They exposed one gap:
UID 1000 could send an ICMP echo to the private host despite zero capabilities.
Setting `net.ipv4.ping_group_range` to `0 0` on Harbor's network sidecar blocked
IPv4 and IPv6 ping sockets while preserving TLS to both model endpoints.
An allowed-SNI request targeting the private TLS fixture did not retrieve its
marker; the fixture's positive control succeeded outside the agent boundary.

Those boundary probes launched no model. Two final candidate cells, one per host,
then completed with the ping restriction on both agent and verifier sidecars.
Both selected handoff and passed the separate verifier. These checks qualify the
combined configuration; they do not change the original twelve comparison scores.

## Evidence against D15's conditions

| Condition | Evidence and limit |
| --- | --- |
| Both hosts finish; skill digests match | Twelve completed trials. Every mounted skill digest matched its arm, and every trial ran the pinned workflow helper. |
| Separate verifier; hidden grader | Fresh verifier containers graded transferred artifacts. Agent health checks confirmed no `/tests` directory. Positive and negative offline grader controls also repeated consistently three times each. |
| Fingerprint fields | Harbor supplied task/skill digests, framework version, requested model/effort, CLI version, and resources. Image and runtime identities were captured separately. A complete D2 run-record writer is still unbuilt. |
| Native usage | Installed `shaka usage --file` read both hosts' session logs. Its normalized prompt and output totals matched Harbor's totals for every inference record. |
| Subscription isolation | Each controller process supplied only its chosen subscription credential. Agent containers received no other host credentials or Docker socket. Temporary credential files were removed after the experiment. |
| Network and traffic | Health checks denied the unrelated endpoint. The confirmation capture recorded 5,335 packets with zero drops and contained both model-endpoint positive controls. No Harbor telemetry or Hub DNS/SNI was observed. |
| Isolation gaps | Init, capability, filesystem, and skill protections used task/Compose configuration. A separate probe closed the default ICMP escape with the sidecar ping setting. Both hosts then completed an additional candidate cell with that restriction on agent and verifier sidecars. Codex required the upload adapter, extending D15's configuration-only remedy. |

The traffic observation covers the two confirmation cells, not a lossless capture
of the entire matrix. DNS queries for blocked destinations remained visible;
the observed application TLS destinations were `api.anthropic.com` and `chatgpt.com`.
Telemetry was disabled and no Hub upload ran. This is bounded observation, not
an exhaustive network-security audit.

Claude's native usage reports routed model `claude-sonnet-5`. Codex reports
configured `gpt-6.1-sol` and medium effort; its routed model remains UNKNOWN.
Under D2, that missing identity keeps affected release comparisons provisional.
Successful execution does not relax that rule.

The verifier called the existing `MergeAuthorization.check` method for this one
scenario. The CLI checks all eight scenarios, so it could not grade one response
without an adapter. No missing model responses were synthesized.

## Cost and decision

Observed inference: **$6.306880 cache-neutral API-equivalent**, within the $50 cap.
That includes 3,059,515 normalized input tokens and 18,785 output tokens across
seventeen model runs: the twelve-cell matrix, the failed Claude verifier attempt,
two traffic confirmations, and two hardened-configuration confirmations.
Setup failures with no model response are
retained as harness errors and do not become task scores.

Pricing uses the pinned rate card's $2/million base input and $10/million output
rates for these profiles. Its SHA-256 is
`f8c09d0f30b9b9795fc1d55bb2c0cbf1c0655dbd5ba07752530cbd17820009af`.
Subscription cash charges were not measured. Delivery and review usage belongs
to the PR's separate usage record.

Recommendation: adopt Harbor as the tier 2 execution layer, including the tested
upload adapter and ping restriction; keep tier 1 in Ruby and tier 3 on its existing driver.
This reuses working host execution, session capture, repetitions, and separate
verification. It adds a pinned Python dependency set, Linux hosting, and an
adapter tied to two Codex paths and a private Harbor method. The default network
policy alone does not meet the proposal's non-TLS boundary.

Maintenance savings over a small Ruby runner remain UNKNOWN: no competing runner
was built or timed. The predecessor's `evaluate-workflow-behavior` and tests at
`d85eceaecac1b8c4d55a7889a806bd89a612a493` provide offline reporting, not execution.
No predecessor workflow, ledger, or policy-engine dependency was imported.

The maintainer must choose the execution layer before the full runner is built.
The next implementation still needs the D1/D2 record and fingerprint schema,
offline publication validators, and a Ruby wrapper enforcing budgets and comparison
rules. This spike activates no recurring job or release gate.

Private evidence includes all attempts, native sessions, pins, task versions,
packet captures, and control results. Credentials and experiment containers were
removed, and the disposable VM was stopped. This public report publishes no raw
run record, transcript, credential, or machine alias.
