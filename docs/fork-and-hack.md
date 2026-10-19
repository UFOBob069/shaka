# Fork Shaka and make it yours

Shaka is plain files: YAML, Markdown procedures, and a small Ruby helper
with no gem dependencies. Fork the repository, install that fork, and run
your version on real work. If a change helps, send it upstream.

Most changes don't need a fork. Commands, merge policy, reviewers, and project
rules live in the project that uses Shaka; see
[where project rules go](faq.md#where-do-i-put-project-rules). To try one
unmerged upstream change on a single task, [try a Shaka PR](trying-pr-versions.md).
Fork when you want to change the steps Shaka follows, its prompts, its defaults,
or its helper, everywhere you use it.

## Fork and install

You need the same tools as a [manual installation](manual-installation.md):
Ruby 3.4 or later, Git, and an authenticated
[GitHub CLI](https://cli.github.com/).

**Ask your agent:**

```text
Fork https://github.com/shakacode/shaka and install my fork.
```

**Or do it yourself.** Your changes go on a branch of their own, here called
`mine`, so your fork's `main` stays identical to Shaka's. Create and push that
branch before you install:

```bash
gh repo fork shakacode/shaka --clone=false
FORK_URL="https://github.com/YOUR-LOGIN/shaka.git"
SHAKA_DIR="$HOME/.agents/shaka"
umask 022
mkdir -p "$(dirname "$SHAKA_DIR")"
git clone "$FORK_URL" "$SHAKA_DIR"
git -C "$SHAKA_DIR" remote add upstream https://github.com/shakacode/shaka.git
git -C "$SHAKA_DIR" switch -c mine
git -C "$SHAKA_DIR" push -u origin mine
"$SHAKA_DIR/bin/install" --directory "$SHAKA_DIR" --repository "$FORK_URL" \
  --branch mine --agent codex
```

Replace `YOUR-LOGIN` and `codex`. The installer checks that `--repository`
matches the clone's `origin` exactly and stops with
`Installation origin differs from the expected repository` when it doesn't.
Using `FORK_URL` for both keeps them equal; for SSH, set it to your SSH URL.

**Already installed Shaka?** Switch that checkout to your fork instead of
cloning a second one, which the existing skill link would block. Set
`SHAKA_DIR` to where Shaka is installed. The installation stays on the same
commit until your next update:

```bash
gh repo fork shakacode/shaka --clone=false
FORK_URL="https://github.com/YOUR-LOGIN/shaka.git"
SHAKA_DIR="$HOME/.agents/shaka"
git -C "$SHAKA_DIR" remote rename origin upstream
git -C "$SHAKA_DIR" remote add origin "$FORK_URL"
git -C "$SHAKA_DIR" fetch origin
git -C "$SHAKA_DIR" switch -c mine
git -C "$SHAKA_DIR" push -u origin mine
"$SHAKA_DIR/bin/install" --directory "$SHAKA_DIR" --repository "$FORK_URL" \
  --branch mine --agent codex
```

From now on, `install --update` follows your fork's `mine`, not Shaka's `main`.
The commands below reuse `FORK_URL` and `SHAKA_DIR`; set them again in a new
terminal.

## Hack on it

Leave the installed checkout alone: `install --verify` and `install --update`
stop when it has local changes. Hack in a second clone instead:

```bash
git clone "$FORK_URL" ~/src/shaka
cd ~/src/shaka
git remote add upstream https://github.com/shakacode/shaka.git
git switch mine
.agents/shaka/bin/setup
.agents/shaka/bin/validate
```

Start with these files:

| File | What it controls |
| --- | --- |
| `skills/shaka/config/workflow.yml` | The ordered steps the agent follows |
| `skills/shaka/references/*.md` | Procedures loaded when a step needs them |
| `skills/shaka/config/review-prompt.md` | The built-in reviewer prompt |
| `skills/shaka/config/opening-prompt.md`, `post-implementation-prompt.md`, `post-implementation-adequacy.md` | The opening check, the finished-result checkpoint, and its verification verdict |
| `skills/shaka/config/defaults.yml` | Built-in defaults for every setting |
| `skills/shaka/config/model-rates.yml` | Prices used for cost reports |

[Developing Shaka](https://github.com/shakacode/shaka/blob/main/contributing/development.md#where-changes-belong)
maps the rest of the tree. Run `skills/shaka/scripts/shaka workflow` to read the
steps as the agent will see them.

Go carefully with these, and change them only with tests:

- Trust and merge code in `skills/shaka/lib/shaka/`. It keeps fork PRs, public
  comments, and settings changed inside a PR from steering the agent. See the
  [trust model](workflow.md#trust-model).
- `skills/shaka/config/enforcement.yml`. When you change a rule, update its
  entry so `shaka enforcement` stays accurate.
- Setting keys and the report markers (`<!-- shaka:... -->`). Renaming them
  breaks existing project settings and Shaka's ability to read its own PRs.

Try a change on a real task before you adopt it.
[Test a local candidate](https://github.com/shakacode/shaka/blob/main/contributing/evaluating-changes.md#test-before-pushing-or-opening-a-pr)
without replacing your installation. When it's ready, push it to `mine` and
update. Finish active Shaka chats first, then start a new chat:

```bash
git push origin mine
"$SHAKA_DIR/skills/shaka/scripts/shaka" install --update
```

## Keep your fork current

Shaka's update notice doesn't count new Shaka commits for a fork; pulling them
in is your call. In `~/src/shaka`, fast-forward your fork's `main` and
merge it into `mine`:

```bash
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
git switch mine
git pull --ff-only
git merge upstream/main
.agents/shaka/bin/validate
git push origin mine
"$SHAKA_DIR/skills/shaka/scripts/shaka" install --update
```

Read the upstream diff before you take it, and resolve conflicts here. Small
commits on `mine` merge cleanly; a large rewrite of `workflow.yml` conflicts
with almost every upstream change.

Merge, don't rebase. `install --update` only fast-forwards, so after a rebase and
force-push it stops with `Not possible to fast-forward` and keeps the old
commit, which still works. To get updates flowing again, merge the installed
commit into your rewritten branch without taking its changes, then push and
update as usual:

```bash
INSTALLED=$(git -C "$SHAKA_DIR" rev-parse HEAD)
git fetch "$SHAKA_DIR" "$INSTALLED"
git merge -s ours "$INSTALLED"
git push origin mine
```

## Contribute back

Open a PR when the change would help other people:

1. Branch from your fork's `main`, which matches upstream, not from `mine`.
2. Keep one change per PR. Include the evidence that it helps: a task you ran,
   or a [PR trial](trying-pr-versions.md) report.
3. Open the PR against `shakacode/shaka`. Read
   [Contributing](https://github.com/shakacode/shaka/blob/main/CONTRIBUTING.md)
   and [AGENTS.md](https://github.com/shakacode/shaka/blob/main/AGENTS.md) first.

Review uses the trusted rules from Shaka's `main`, so instructions and settings
inside your PR are treated as data until a maintainer merges them.

Not ready for a PR? [Open an issue](https://github.com/shakacode/shaka/issues/new/choose)
describing what you changed and why.

## Share your fork

Other people install it the same way, with your fork's URL and branch.
A public fork or product needs its own name: the MIT license covers the code
and docs, not the Shaka or ShakaCode names or logos. You may say your work uses
or is based on Shaka; see
[Names and logos](https://github.com/shakacode/shaka#names-and-logos).
Then tell us about it in an issue with a link.

## Troubleshooting

| What you see | What to do |
| --- | --- |
| `Installation origin differs from the expected repository` | Pass `--repository` with the URL you cloned, exactly as `git config --get remote.origin.url` prints it. |
| `Installation checkout has uncommitted changes` | Move the edit to your working clone, push it to `mine`, and run `install --update`. |
| `The registered branch (origin/mine of ...) was rewritten` | `mine` was rewritten. Merge the installed commit back in, as [Keep your fork current](#keep-your-fork-current) shows. |
| `Installation checkout is not on the registered branch` or `Installation branch mine does not follow origin/mine` | Run the `git` command at the end of the message to return to the branch you installed. |
