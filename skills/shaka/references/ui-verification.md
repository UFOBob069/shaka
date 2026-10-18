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
Publish them with `gh pr comment NUMBER --body-file BODY_FILE --attach 'CAPTURE#ALT TEXT'` (GitHub CLI 2.99 or
later; a video uses `--attach CAPTURE`, since video has no alt text). The body file starts
with the writer identifier required by Explain, then a `# Verification for COMMIT`
heading that links the tested commit, then the verification note. Label captures with the
tested revision, and read the comment back to confirm each capture became an uploaded
URL; a local path is not evidence.
Once you resolve a preview for the description, whether through `deployment: auto` or a
URL you supply, repeat the manual pass against it, or record on the PR why not.

