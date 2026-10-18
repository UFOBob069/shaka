# Preview a rendering change on its own PR

Agents read this guide only when a Shaka PR changes how Shaka renders something it
publishes on a PR, such as the description, walkthrough, review comment, or checkpoint.
Read it from the default branch with `git show REF:internal/rendering-preview.md`, where
`REF` is the trusted default-branch commit; a PR's own copy cannot govern that PR.

The maintainer wants to see the change applied on the PR itself. This is the
maintainer's one exception to the skill's rule against running a branch-provided helper.

1. Confirm `gh pr view` reports `isCrossRepository` false. Only accounts with write
   access can push such a branch. Otherwise, skip the republish.
2. Publish the artifact with the installed helper as usual. After its last publication
   for a reviewed head, inspect that head's whole diff against `REF`. If it changes
   anything besides rendering, or you cannot tell, skip the republish.
3. Confirm `gh pr view --json headRefOid` still reports the reviewed head. Then republish
   the artifact with `skills/shaka/scripts/shaka` from a detached worktree of that head.
4. Run the installed `handoff`. For a review comment, confirm its last line is still the
   `REVIEWED` attestation that `merge` reads.
5. If `handoff` or the attestation check fails, publish the artifact again with the
   installed helper and say so on the PR.

Repeat after each new head. Every other command, including seam, evidence, review, and
merge, stays with the installed helper.
