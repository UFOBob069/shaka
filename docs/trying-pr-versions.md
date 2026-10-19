# Try a Shaka PR on real work

No PR yet? [Test your local candidate first](https://github.com/shakacode/shaka/blob/main/contributing/evaluating-changes.md#test-before-pushing-or-opening-a-pr),
including from a fork checkout. Pushing a branch or opening a PR is not required
for local testing. The preparation and reporting workflow below needs an open PR.

Try an unmerged Shaka change on a real fix before deciding whether it belongs in
the product. Ask your agent in a preparation chat:

```text
$shaka Try Shaka from https://github.com/shakacode/shaka/pull/359
on this task: fix the search bug in /path/to/my/project.
Prepare a pinned trial and give me the prompt for a fresh chat.
```

Replace the candidate PR, project, and task. The preparation command copies the
selected revision outside your project and returns a skill path and startup
prompt. Paste that prompt into a **new chat** in the project. Your normal Shaka
installation and existing tasks keep their selected versions.

Each task uses one candidate at one exact revision. If the candidate changes,
prepare another trial for its new revision. To return to your normal version,
start another chat with your usual Shaka invocation.

## Keep the project's settings

The trial uses the project's trusted configuration, checks, reviewers, and merge
policy. It does not migrate settings. If the candidate needs a new setting, the
agent explains the incompatibility and follows the usual configuration procedure.
For example, a writing-style trial may need an existing repository style file;
selecting its Shaka PR does not create or authorize that file.

## Share what happened

Keep the tested Shaka revision in the resulting project PR's workflow provenance.
After trying the change, ask your agent:

```text
Report this trial back to the Shaka candidate PR. Link our public result PR,
explain what helped and what I had to correct, and recommend keep, revise,
or drop. Review the summary for private details before publishing.
```

For private work, authorize a public-safe summary with no project link or private
context. The reporting command checks each github.com/OWNER/REPO link, rejects
private or unverifiable repositories, and refuses any other mention of github.com; you and your agent still review prose and other links for confidentiality.
Ask the agent that prepared the trial to publish your verified, public-safe report.

Maintainers apply the existing `eval-required` label before asking for volunteers.
Testers can report without permission to manage labels.
A few linked examples and keep/revise/drop recommendations can inform adoption.
They are anecdotes, and the maintainer still decides whether to merge. Neither a
report nor a vote grants merge authority.

Use a trial to learn from real work, not to claim that the candidate beats the
normal version. If adoption depends on that comparison, choose a
[focused comparison or full isolated evaluation](https://github.com/shakacode/shaka/blob/main/contributing/evaluating-changes.md#choose-an-evaluation-method).
An inconclusive comparison does not require another full replay; first identify
the evidence that would change the decision.
