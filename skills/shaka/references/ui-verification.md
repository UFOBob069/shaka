# Verify a UI change

For UI changes, read this procedure before review and publication. Keep the workflow's validation,
review, publication, and Finish gates; these procedures supply the evidence
those gates require.

## UI changes

For UI changes, meaning anything a person sees on screen other than command-line output,
use the change by hand on the head you will push, and capture before and after screenshots
on desktop and mobile, adding a short video when interaction or timing matters. Inspect each capture
for the intended state and compare the whole affected view for unexpected changes.
Present an annotated after capture with a few numbered boxes, highlights, or arrows
explaining meaningful changes, following the [visual-evidence procedure](visual-diff.md).
Keep the original before and after captures available, label intended and unexpected
changes, and explain any alignment limits. Exact pixel differences are optional
diagnostic evidence; put them in collapsed details when useful.
After a later commit that changes runtime behavior, repeat the manual pass and refresh
the affected captures and annotations, including any diagnostic differences.
Read the current public
[verification guide](https://github.com/shakacode/shaka/blob/main/docs/pr-verification.md) for examples when deciding what evidence a
change needs. Follow this installed workflow if the current public guide differs.

## Publish UI evidence

Check captures for credentials as part of the workflow's privacy inspection.
Publish them with the saved helper's
`ui-check OWNER/REPO NUMBER --head SHA --content-file PATH` (GitHub CLI 2.99 or later). The
content JSON holds `identity`, the Explain writer fields; `body`, the verification note;
`captures`, each `PATH#ALT TEXT` (a video takes its path alone, since it has no alt text);
and optional `retire` and `earlier`. List in `earlier` the comment IDs of this PR's open UI
checks posted before this command, which it cannot recognize alone. To place a capture, reference its path in `body` as a Markdown image; an unreferenced one
is appended. The command adds the writer line and the heading that links
the head, confirms each capture uploaded, and folds this account's earlier UI checks.
Label captures with the tested revision.
A UI check for a newer head carries all of the PR's current UI evidence. For a view the
newer commits leave unchanged, say so and embed its earlier uploaded captures, labeled with
the revision they show, or repeat the note recording why a capture could not be published;
a link to the older comment does not replace it. The command refuses a check that leaves
out a capture an open earlier check shows; embed it, or list its URL in `retire` when a new
capture replaces it. When the result lists `unavailable` folds, fold those with `review collapse`.
Once you resolve a preview for the description, whether through `deployment: auto` or a
URL you supply, repeat the manual pass against it, or record on the PR why not.

