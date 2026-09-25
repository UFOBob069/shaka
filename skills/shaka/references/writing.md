# Writing guidance

Before publishing, reread each summary for these points:

- Lead with the outcome its reader notices.
- Give each sentence one main idea and a clear subject and verb.
- Put conditions beside the behavior they limit.
- Use familiar words; explain necessary technical terms.
- Keep exact commands, identifiers, risks, and evidence intact.
- In replies, state the decision and use the thread's existing context.
- Delete greetings, praise, repeated explanations, and claims of significance
  that add no information.

For example, replace “Adds validation of the configured base parameter” with
“Shaka now rejects an invalid base branch before the agent starts work.” A code
walkthrough can then explain the validation and its edge cases.

Use `writing_style.guide` from trusted `shaka seam check` output when the repository
has `.agents/writing-style.md`. When trusted `AGENTS.md` exists, read its writing
preferences and linked style files from the trusted branch. Current task
instructions take precedence, followed by user-level writing instructions,
trusted `AGENTS.md`, then the conventional style defaults. Use the guidance above in every
repository; current task instructions can refine it. No style schema or prose
score is needed beyond the limits below. Self-edit the content JSON; do not rewrite the rendered GitHub
body or invoke a separate rewriting skill for Shaka's publication step.

## Point readers to the code

Reviewing code is easier than reading a wall of text about it. The diff already
shows what changed, so prose should say why, flag what needs a close look, and
link to it. A description sends the reader to the walkthrough; a walkthrough
links each step to the lines it explains.

Keep the text in proportion to the change. A three-line fix needs a sentence or
two, not a page. Describe the result at this head; review rounds belong in the
description's collapsed history, not in its visible sections.

Aim for sentences under 25 words and paragraphs of about four sentences.
`description` and `walkthrough` refuse text past the
[prose limits](https://github.com/shakacode/shaka/blob/main/docs/settings.md#prose_limits): long sentences, long
paragraphs, or more visible words than the change warrants. Split the text,
collapse supporting detail into `details`, or link to the code, then publish again.
Record each refusal in the description's review history details: what it
reported, a quoted passage or the word count, and what you changed.

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
