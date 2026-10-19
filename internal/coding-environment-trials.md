# Coding-environment trials record

These are dated observations, not a current support matrix. On September 23, 2026,
the maintainer reported additional team use of Pi and OpenCode beyond these
recorded trials. The observations below retain their original dates and limits.
For installation, see [development environments](../docs/coding-agents.md).

## September 2026 trials

These observations were made on September 14, 15, and 17, 2026. A successful install or CLI
startup does not establish a complete workflow, and workflow success does not
establish complete usage attribution.

| Capability | Codex CLI 0.154.0 | Claude Code desktop 2.1.270, CLI 2.1.272 | Cursor CLI 2026.09.10-fd3934a | OpenCode 1.18.31 | Pi 0.85.1 |
| --- | --- | --- | --- | --- | --- |
| Installation and startup | Dedicated skill installation and explicit trusted-file startup checked. | A symlinked personal skill loaded in the desktop app and in `claude -p`; `/shaka` asked for the task and merge preference and stopped before edits. A same-named repository skill did not replace it. | Dedicated CLI package version/help checked; Cursor skill instruction activation unverified. | Canonical `~/.config/opencode/skills` install documented; TUI activation trial pending. | Shared Agent Skill loaded from a trusted external source; no Pi-specific copy or launcher. |
| OS write boundary | A native workspace sandbox denied writes to the separate trusted source, installed link, and link directory while allowing the session and target checkout. | No launcher or sandbox; the user's permission mode applies. Not separately probed. | Native Cursor sandbox boundary unverified. | No launcher sandbox; the user's permission mode applies. The launcher disables project-local discovery so the target's `.opencode` plugins, config and instructions never load. Not separately probed. | The user's Pi tool permissions apply; no separate boundary was probed. |
| Real workflow | Protected PR operations exercised with Shaka. A fresh CLI task implemented and verified the Astro website guides using its repository instructions; the owning task handled publication. | One consumer PR delivered end to end on September 17, 2026: agent-workflows-com#62, branch through TDD, seam validation, five review rounds, helper-published description and walkthrough, helper merge in Ask mode. | Consumer delivery unverified. | Consumer delivery unverified. | The Pi usage-reader implementation was the first recorded delivery trial; broader consumer evidence remained pending. |
| Usage | Reader matched 14 real CLI responses and repeated-source input without double counting; attribution remains partial. | Reader matched an independent per-response aggregate for a desktop session with a subagent and two models, and Claude Code's own totals for two CLI runs. | Stop-hook reader works against captured desktop `3.20.21` `grok-4.6` payloads, but has not produced records in a real delivery ([#111](https://github.com/shakacode/shaka/pull/111)); transcripts and bubble `tokenCount` remain unused. | Export reader matched an independent per-response aggregate for a real 49-response session (all counters, interval, version); the session must be named with `--session` and attribution remains partial. | Reader matched an independent aggregate of selected active-branch responses, including reasoning and native nominal cost; abandoned branches were excluded. Compaction, branch-summary, and tool-nested model usage remain excluded. |

The Codex write test establishes that particular local boundary. It does not
establish equivalent behavior in the desktop app, other versions, or other hosts.
Repeated consumer use, including failed checks, changed PR heads, and Ask/Auto
stopping behavior, is still required before claiming broader adoption.

## October 2026 feedback-resumption trial

These observations were made on October 4, 2026 for
[#419](https://github.com/shakacode/shaka/issues/419). They cover one Claude Code
desktop session and one Codex desktop session. They do not establish the same
behavior in other versions, hosts, or sessions. Times are UTC.

| Fact | Claude Code desktop 2.1.283 | Codex desktop, version UNKNOWN |
| --- | --- | --- |
| Shaka revision | `78fd6ebd336aec38751cce9bfb804cf869155225` | `0ea84cb3698dbcb06ddb72392c85be02f1c2c149` |
| Resumption mechanism tested | A command started with the `Bash` tool's `run_in_background` option. When it exits, the host starts a new turn in the owning chat. | A command session left running when the turn ended. |
| Probe result | Observed: a 45-second command started at 08:47:57, finished at 08:48:42, and a new turn began at 08:48:49 with no user message between. | Observed: the command finished at 07:00:34 and no turn followed until the user's next message. |
| Merge preference | Ask | Ask |

The probe isolates host resumption from GitHub detection. It does not show that
`pr watch --comments-only` resumes a chat after an Ask handoff.

### Live feedback cases

Each case is recorded as observed, simulated, or not yet run. A simulation is an
action the agent's own GitHub account performed in place of a maintainer.

| Case | Result |
| --- | --- |
| Ordinary comment resumes the chat | Not yet run |
| Review summary resumes the chat | Not yet run |
| Inline comment resumes the chat | Not yet run |
| Actionable feedback withdraws merge readiness | Not yet run |
| No duplicate reply after a monitor restart | Not yet run |
| Monitor expiry and renewal | Not yet run |
| Changed Owner value | Not yet run |
| Confirmed ownership transfer | Not yet run |
| PR closure | Not yet run |
| Unavailable resumption names a person and resume prompt | Not yet run |
