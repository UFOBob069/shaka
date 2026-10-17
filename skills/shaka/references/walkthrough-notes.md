# Walkthrough notes

Read this only when supplying walkthrough `notes` or handling a note thread.

A note is an inline comment in the walkthrough review that guides the reviewer's
reading on the lines it is about. It is neither a finding nor a to-do, and the
walkthrough body still carries order, purpose, validation, risk, and rollback.
Add a note only where a pointer on the line saves the reviewer a search, such as
where to start, a risky spot to read closely, a mechanical move to skim, or the
alternative the code invites and you rejected.

Place text elsewhere when it fits better: a code comment or clearer code for what
a future maintainer needs, the description for what affects the merge decision,
and a change for what asks for one.

Give each note one idea and leave most lines without one. Anchor only on lines the
PR diff shows; GitHub refuses the whole review otherwise, and the command names
each note's location in its error. Notes count toward the walkthrough's prose limits.

The command refuses notes when the base branch requires conversation resolution,
because the current notes stay open until a newer walkthrough replaces them;
publish that walkthrough without notes. A newer walkthrough resolves the older
notes that have no reply. Answer a note with a reply like any review thread, then
resolve it.
