# Verify a Codex tower's project

Verify the selected chat's native ID, host, and working directory. Run the
filesystem and Git checks on that chat's host. If native metadata or the required
host reads are unavailable, stop setup or registration without acknowledging it;
report the missing read and restore access before retrying.

Resolve an explicit native `projectId` through the native project list on the
task's host. If that ID is absent from the list or its project does not contain
the selected Git root (including a worktree derived from that project), stop as
ambiguous. An invalid explicit association cannot use the fallback below.

When `projectId` is null or omitted, resolve the task's native working directory
and the selected checkout through Git to the same canonical repository root.
Perform filesystem and Git resolution on the task's host. Require exactly one
registered filesystem project with that host ID whose real path equals that
canonical root. Compare resolved filesystem paths, not labels or textual path
prefixes. Zero or multiple matches stop as ambiguous; a matching
parent folder is insufficient for this fallback. Record the project's ID, path,
and that it was resolved by path rather than explicitly attached to the task.
This fallback does not change the task's saved project association.
