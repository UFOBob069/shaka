# Shared writing rules

- Use these rules for publication prose and checkpoint reports.
- When trusted `AGENTS.md` exists, read its writing preferences and any Markdown
  style file it explicitly points to. Those preferences take precedence; current
  task instructions can refine them.

## Plain language and organization

- Prefer lists for instructions, findings, and explanations with multiple points.
  Use numbered lists when order matters or readers need to refer to individual points.
- Lead with the outcome its reader notices.
- Give each sentence one main idea and a clear subject and verb.
- Make the subject a person who acts, or a thing doing what things do. Do not give
  a repository, setting, or file a person's verb such as "see" or "know".
  - Instead of: “A repository can now name the providers whose reviewers read
    every commit, and see on the PR when one could not.”
  - Write: “Maintainers can now list the AI providers that review every commit.
    When one cannot review, the review comment says so.”
- Put conditions beside the behavior they limit.
- Use familiar words; explain unfamiliar project terms through the behavior they name.
- Name the feature, user, or dependency behind references to an agreed design
  or earlier discussion; supply the context the reader needs.
- Keep exact commands, identifiers, risks, and evidence intact.
- Delete greetings, praise, and claims of significance that add no information.
  State each visible conclusion once; different wording or labels do not add meaning.
- Describe observable behavior rather than implementation jargon. For example:
  - Instead of: “Adds validation of the configured base parameter.”
  - Write: “Shaka now rejects an invalid base branch before the agent starts work.”
- Keep explanations proportional to the change. Aim for sentences under 25 words
  and paragraphs of about four sentences when prose is useful.

## Review evidence

- Put the current-head recommendation, main reason, and next action before analysis.
- Name model settings with their provenance; a configured model is not proof of a served model.
- Name the user benefit, scope, and unfinished verification when they affect the decision.
- Distinguish verified results, a recommendation to merge, and permission to merge.
  Keep unresolved blockers visible.
- State whether a simpler alternative revises this PR or replaces it.
- Supporting usage and history can remain collapsed.
- State a risk as who or what is affected and what they would see fail: “API
  clients get a 500 until the cache warms,” not “medium blast radius.”
- State what reverting a commit restores and what it leaves:
  - Reverting code does not restore deleted or rewritten stored data.
  - It does not undo outside effects such as sent email, charges, or published packages.
  - Name each such effect and how to recover from it, or that it cannot be recovered.
