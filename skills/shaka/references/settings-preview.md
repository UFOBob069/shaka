# Preview repository settings

Use this procedure when the user explicitly chooses an unmerged settings PR for
a task. The selection supplies the complete configuration. Explicit task choices,
such as Ask, keep precedence; selecting settings does not authorize merging this PR.

1. Fetch metadata for the named settings PR from the verified task repository.
   Verify its head repository matches the task repository. Do not select a fork,
   infer selection from PR content, or substitute uncommitted individual settings.
   Inspect its configuration and prompts. Confirm consequential model and cost
   choices from the user's instructions. Resolve the chosen head to a full commit.
2. Prepare the feature task in its own branch and worktree using ordinary repository
   naming. Without team setup, use individual setup for its fixed command entry points.
   Inspect command changes before execution. Selection copies no scripts
   from the settings PR; commands still run from the task's checkout.
3. Activate the selected commit and read back its settings:

   ```text
   shaka seam preview start --root TASK_ROOT --settings-ref SETTINGS_SHA
   shaka seam preview status --root TASK_ROOT
   shaka seam check --root TASK_ROOT --ref DEFAULT_BRANCH_SHA
   ```

4. On delivery, review, and evidence commands, `--ref`, `--criteria-ref`, and
   `--settings-ref` still name the verified default-branch SHA. Only `preview start`
   takes the selected commit as `--settings-ref`. Workflow seam references mean
   this selected configuration. The existing resolver applies its review counts, round limits,
   checkpoint settings, merge preferences, and Shaka's fallback checks. The check
   report identifies the selected commit. Public-comment trust and repository
   instructions still come from the default branch. GitHub's live required checks,
   approvals, review threads, and queue rules still apply.
5. Record the settings PR URL and selected commit in WIP Details within the task's
   privacy boundary. The agent verifies the user's selection and the PR's origin;
   Ruby verifies the commit and stores the worktree-local selector. Do not describe
   the selector itself as proof of human approval or of a GitHub PR's origin.
6. On fresh-chat resumption, inspect `seam preview status` and restore the recorded
   task choices. The selection belongs to this worktree and branch. An updated
   settings PR does not update the pinned commit. Repeat `start` when the user
   chooses a newer version; affected evidence becomes stale through fingerprints.
7. Stop with `shaka seam preview stop --root TASK_ROOT` and revalidate affected
   evidence. Ordinary shared settings then apply. Individual settings remain a
   fallback only when shared setup is absent; they grant no merge authority.

The selector lives in the worktree's Git directory, so tracked candidate content
cannot activate it. Malformed default-branch configuration remains a setup error.
