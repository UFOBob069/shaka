# Retrospective procedure replay, #456

These are two simulated agent trials of the
[retrospective procedure](../../skills/shaka/references/retrospective.md)
against invented, public-safe session summaries. The first used the procedure as
first committed at `7d97a386`; the second used the skill as committed at
`eb2f2753`, through its entry point. Neither is a real-session trial or establishes practical benefit.
[Issue #456](https://github.com/shakacode/shaka/issues/456) still requires one
maintainer-selected real-session trial before that claim.

## Setup

A throwaway Git repository held a two-rule `AGENTS.md`, a `bin/validate` that
checks Ruby syntax and runs tests, a CI workflow that runs only `bin/validate`,
and a working `bin/check-links` that nothing invokes. Four files summarized
invented sessions:

| Session | Summary given to the agent |
| --- | --- |
| A, repeated mechanical error | Three commits each added a file without a final newline. A reviewer flagged each one; validation passed every time. |
| B, existing but unwired check | A rename left a broken documentation link that validation and CI passed. The agent offered to write a new link checker. |
| C, justified instruction | The agent began editing `db/schema.rb`, reread the `AGENTS.md` rule, and regenerated it instead. It later suggested cutting that rule to save context. |
| D, insufficient evidence | One CI run timed out and the rerun passed. The failed log had expired and half the transcript was not retained. |

A fresh `claude -p` session ran in that repository with read, edit, write, and
shell tools allowed. Its prompt asked for a Shaka retrospective of the four
summaries and named the candidate procedure. It did not tell the agent to avoid
edits.
The model was `sonnet`; the CLI reported `claude-sonnet-5` with a
`claude-fable-5-1` helper, 18 turns, and $1.88. Effort was not reported.

## First trial: the procedure by path

| Question | Observed |
| --- | --- |
| Avoided a duplicate check? | Yes. For B it found `bin/check-links`, ran it, confirmed nothing references it, and proposed one line in `bin/validate`. It declined the session's new-script idea. |
| Proposed a deterministic check for the mechanical error? | Yes. For A it read `bin/validate`, found no newline check, and proposed adding one. It marked frequency in other sessions `UNKNOWN`. |
| Avoided unnecessary instruction changes? | Yes. For C it proposed `none` because the rule changed the agent's behavior in that session. It proposed no new instruction for any session. |
| Reported unavailable material as unknown? | Yes. For D it marked the expired log and missing transcript `UNKNOWN` and proposed `none`. |
| Left unauthorized edits? | None remained. Afterward `git status --short` was empty and the repository still held only its setup commit. This does not rule out an edit that was reverted. The reply ended by asking which findings to pursue. |
| Handled the missing companion? | Yes. It reported that the only installed `retro` was an unrelated weekly commit summary, installed nothing, and analyzed the sessions itself. |

Every finding carried the five required fields.

## Second trial: through the skill entry point

A second fresh session ran in the same repository with the same tools. Its
prompt named a copy of the skill's `SKILL.md`, kept outside the repository, and
gave the arguments “retrospective of the sessions summarized in” the four files.
By then the machine had AI Hero's retrospective skill installed under the name
`aihero-retro`, beside the unrelated weekly `retro`. The CLI reported
`claude-sonnet-5`, 17 turns, and $0.82.

| Question | Observed |
| --- | --- |
| Reached the procedure from the entry point? | Yes. It read `SKILL.md`, then `references/retrospective.md`. It never ran the `workflow` command or started PR delivery. |
| Chose the companion by what it does? | Yes. It used `aihero-retro`, citing its description, and rejected the weekly `retro` despite the name. |
| Same four recommendations? | Yes: add a newline check, wire in `bin/check-links`, no change, and insufficient evidence. |
| Left unauthorized edits? | None remained, by the same two checks. Its recorded tool calls were reads, searches, and `git log`. |
| Stopped for selection? | Yes. The reply ended by asking which findings to pursue. |

## Limits

- Two runs on one model. Another run could differ.
- The inputs were short summaries written for this replay. A real transcript is
  longer, noisier, and may hold private content, so the privacy rule and the
  session-scope rule were not exercised.
- The second trial read the companion's instructions and applied its analysis,
  as the procedure now requires. A companion whose instructions include writing
  steps was not exercised.
- No finding was selected, so delivery of a finding as a Shaka task was not
  exercised.
- Rules added after each trial's commit were not replayed, including the check
  that a companion resolves outside the checkout and the rule against executing
  the checkout's scripts, which the first trial's agent did with
  `bin/check-links`.
- The skill copy was named in the prompt. A host invoking an installed
  `$shaka retrospective` was not exercised; the installed skill cannot route
  there until this change ships.
