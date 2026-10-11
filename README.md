# Shaka

**Work effectively with your coding agent, from task to human-readable PR.**

Shaka guides your coding agent through implementation, testing, independent
review, and PR delivery. Get a clear handoff: what changed, what was checked,
and what needs your decision—with the context to approve the change, request
revisions, or resolve an open question.

[Read the Shaka documentation](https://shaka.shakacode.com/).

<a id="example-prompts"></a>
<a id="get-started"></a>

## Start with a small task

[Install Shaka](docs/getting-started.md), then give it a task:

```text
$shaka <task or issue link>
```

Examples use Codex. Use `/shaka` in Claude Code, Cursor, or OpenCode; in Pi,
load the installed skill. You can describe an outcome or provide an issue link.
If setup is missing, Shaka asks whether you want individual or team settings,
finds your existing checks, and defaults to Ask.
`Go` starts with your agent's current model and effort settings.
[Working with Shaka](docs/working-with-shaka.md) covers practical prompts,
merge choices, feedback, and resuming work.

## Why use it?

- **Catch problems before hitting CI.** Test and review locally, including
  adversarial review, then fix problems before pushing. Fewer repeat CI runs can
  lower costs and shorten CI queues.
- **Make review easier.** Get a clear PR description, screenshots showing visible
  changes, and a code walkthrough explaining implementation choices and alternatives.
- **See what was checked and what it cost.** Find the tested revision, review
  findings, verification gaps, and available model, usage, and cost information.
- **Reduce prompt-injection exposure in open source.** Shaka’s comment reader
  withholds untrusted authors’ comments from the agent for maintainer triage.
  [Review safety](docs/workflow.md#trust-model) explains the boundary.
- **Use one workflow across projects.** Each repository configures its own checks,
  reviewers, and merge policy. [Repository setup](docs/configure-repository.md#use-shaka-across-projects)
  connects Shaka to your existing tools.
- **Control merging.** Choose **Ask** to merge yourself or approve the agent's merge,
  or **Auto** to let it merge after required checks and approvals.
  Consequential changes need human review.
- **Spend less time directing the process.** Describe the outcome. Shaka supplies
  the steps using your coding agent, repository scripts, and GitHub. WIP Details
  identify unfinished work and the next action when you need to resume.

[See what a Shaka PR gives you](docs/pr-verification.md#read-a-pr-for-your-decision).

<a id="requirements"></a>

## What you need

Ruby 3.4 or later, Git, an authenticated [GitHub CLI](https://cli.github.com/), and
[a coding agent](docs/coding-agents.md) that can load skills and run commands.
The installation prompt lets your agent check these for you.

See [what to expect from Shaka](docs/expected-experience.md) for setup choices,
verification gaps, and help resuming work when checks or access fail.

## Documentation

- [Start here](docs/getting-started.md) — install, configure, and run a first task.
- [Working with Shaka](docs/working-with-shaka.md) — results, decisions, and useful tips.
- [Workflow and review safety](docs/workflow.md) — the process, trusted feedback, and what checks enforce.
- [FAQ](docs/faq.md) — answers to common questions.
- [Documentation index](docs/README.md) — setup, verification, settings, and advanced guides.

[Contributing](CONTRIBUTING.md) · [MIT license](LICENSE)
