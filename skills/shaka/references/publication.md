# Publication procedure

- Before publishing, read [the shared writing rules](writing.md) and use them
  alongside the instructions here.
- In replies, state the decision; use shared context without requiring private discussion.
- Self-edit the content JSON; do not rewrite the rendered GitHub body or invoke a
  separate rewriting skill for Shaka's publication step.
- No style schema or prose score is needed beyond the limits below.

## Post-implementation comments

- The renderer supplies the order, labels, and the reviewer's evaluation and concerns.
  Write the owner's `reason` and `next_action` as
  [the checkpoint procedure](post-implementation-validation.md#recommend-the-next-action) describes.
- Use this example for content, not exact wording or claims:

  > **Recommended next action:** {What should happen to this PR}
  >
  > {Affected users} can now {specific behavior}. {Main reason for the recommendation}.
  >
  > **Next action:** {Action and applicable dependencies, checks, or approvals}.

- Replace every slot with concrete task facts and actual evidence.

## Point readers to the code

- The diff already shows what changed. Say why, flag what needs a close look, and link to it.
- A description sends the reader to the walkthrough; a walkthrough links each step
  to the lines it explains.
- Describe the result at this head. Review rounds belong in the description's
  collapsed history, not in its visible sections.
- `description` and `walkthrough` refuse text past the
  [prose limits](https://github.com/shakacode/shaka/blob/main/docs/settings.md#prose_limits):
  long sentences, long paragraphs, or more visible words than the change warrants.
- Split the text, collapse supporting detail into `details`, or link to the code,
  then publish again.
- Record each refusal in the description's review history details: what it reported,
  a quoted passage or the word count, and what you changed.
