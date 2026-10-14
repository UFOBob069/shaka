# Shared writing rules

- Use these rules for publication prose and checkpoint reports.
- When trusted `AGENTS.md` exists, read its writing preferences and any Markdown
  style file it explicitly points to. Those preferences take precedence; current
  task instructions can refine them.

- Apply `writing_style.guide` from trusted seam output as repository defaults when present.

## Plain language and organization

- Prefer lists for instructions, findings, and explanations with multiple points.
  Use numbered lists when order matters or readers need to refer to individual points.
- Lead with the outcome its reader notices.
- Give each sentence one main idea and a clear subject and verb.
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

## Loading repository defaults

`shaka seam check --root ROOT --ref SHA` reads the optional
`.agents/writing-style.md` from the same resolved default-branch commit as the
repository settings. It returns the text as `writing_style.guide`. A candidate
change cannot replace that guide while its own PR is being described.

The file must be non-empty UTF-8 text in a regular file, at most 100 KiB.
The loader checks size before reading content and rejects symlinks, directories,
and submodules. Markdown is the convention, not a syntax check.

Local and implicit candidate checks validate the file without returning its
prose; invalid candidate files fail the check. Under `--ref`, an invalid guide
instead produces a warning on stderr and in `writing_style_warning`, and the
guide is omitted. Report the problem and continue using the remaining writing
instructions. Required repository policy stays available.

`shaka doctor` checks repository configuration but does not validate this style
file. Use `shaka seam check --root ROOT --local` to check a candidate file.
For an existing `AGENTS.md` pointer to this conventional path, replace any symlink
with a regular file before adopting automatic loading. Other style-file pointers
remain supported through the trusted `AGENTS.md` instructions above.

Ruby verifies file loading and validation, not writing quality or compliance
with the guide. Applying preferences and resolving their precedence remain agent
responsibilities; review actual output before claiming improved writing.
