# Coding agents

Your coding agent supplies the model, permissions, and tools. Install Shaka once
and use it across your repositories.

| Coding agent | Start a task | Notes |
| --- | --- | --- |
| Codex | `$shaka` | Desktop app or CLI; the optional RCT skill needs desktop task tools |
| Claude Code | `/shaka` | Desktop app or CLI; Claude tower skills need desktop session tools |
| Cursor | `/shaka` | Start a new Agent chat after installation |
| OpenCode | `/shaka` | Use the installed skill in a session; an optional launcher is also available |
| Pi | Load the installed Shaka skill | Uses Pi's existing permissions; no separate Shaka launcher |

Use the [installation prompt](getting-started.md); the agent follows the
[installation reference](../skills/shaka/references/installation.md) for your environment.

The opt-in [DeepSeek reviewer](settings.md#reviewlocal_review_agents) runs through
Shaka's Ruby OpenRouter API adapter. It does not require native DeepSeek support in
Codex, Claude Code or Cursor, and does not change the coding host's model.
Local hosts need Ruby, outbound HTTPS and `OPENROUTER_API_KEY` in the process that
runs Shaka. A Cursor cloud agent or CI job also needs those capabilities and an
explicit secret provision; local environment variables are not automatically
available there. Cloud execution and reviewer quality require a live trial in
that environment; deterministic adapter tests do not establish either.

To support another coding agent, [contribute](../CONTRIBUTING.md) installation
instructions, a demonstrated task, and known limitations. Keep environment-specific
code separate from the shared workflow.

## Codex desktop follow-up

Shaka tells you who will handle later PR feedback. If automatic follow-up
is unavailable, the handoff names someone to check feedback and gives them
a prompt to resume the chat. Ask merging still waits for your decision.
