# Understanding PR timings

A PR's **Timings** section, just below **Usage and cost**, shows where the
PR's time went. It separates the stretches when the agent was working from
the stretches when the PR was waiting for you. Use it to see how long each
checkpoint took to reach and how long each one waited for a person to respond.

Here is an example:

| Stretch | From | To | Time |
| --- | --- | --- | ---: |
| Before the pull request | 2026-10-18 07:54 | 2026-10-18 08:26 (opened) | 32m |
| Between checkpoints | 2026-10-18 08:26 | 2026-10-18 09:54 | 1h 28m |
| Waiting on a person: answer | 2026-10-18 09:54 | 2026-10-18 19:36 (resumed) | 9h 41m |
| Between checkpoints | 2026-10-18 19:36 | 2026-10-18 21:54 | 2h 18m |
| Waiting on a person: merge approval | 2026-10-18 21:54 | 2026-10-18 23:15 (merged) | 1h 21m |

The section opens with totals for both kinds of time, for example
`Totals: 4h 18m between checkpoints · 11h 2m waiting on a person in 2 waits`.
The first total includes the time before the PR opened.

## What each stretch means

| Stretch | Starts | Ends |
| --- | --- | --- |
| Before the pull request | The PR's first commit | The PR opens |
| Between checkpoints | The PR opens, or a wait ends | The next wait starts, the PR merges or closes, or this update |
| Waiting on a person | The agent asks for your answer, your merge approval, or a manual resume | The agent resumes, or the PR merges or closes |

Shaka reads these times from GitHub every time it updates the description. A
wait is the time one of the attention labels stayed on the PR:
`awaiting-answer`, `awaiting-merge-approval`, or `awaiting-resume`. The agent
adds a label when it stops for you and removes it when work resumes.

## Read the limits

- Times are UTC wall-clock time and include nights and weekends.
- A wait ends when the agent resumes, which can be slightly after you replied.
- Time between checkpoints includes the agent's work, checks running, and any
  wait the agent did not mark with a label.
- The timeline starts at the first commit, so work before that is not counted.
  A rebase can move that date; when it falls after the PR opened, the first row is omitted.
- Every labeled wait counts, however short. A wait of a few seconds can be a
  quick reply or the agent relabeling the PR; the label history cannot tell them apart.
- When a PR has waited many times, the table shows the latest 30 stretches. The
  totals still include every stretch.
- The description shows timings as of its last update. The agent asks for your
  merge approval after that update, so when you merge on GitHub yourself, the
  final wait appears only if the agent updates the description again.

If GitHub cannot supply the timeline, the section says so and the rest of the
description still publishes. The next update tries again.

[Usage and cost](usage-and-cost.md) explains the section beside it.
