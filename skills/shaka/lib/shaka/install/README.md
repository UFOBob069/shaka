# Installer terms

Official installation links skills into a dedicated clean checkout, with local Git,
Ruby, and link records under `.git`. `Checkout` guards updates; `OfficialLinks`
reuses atomic link replacement without removing old copies.
Explicit managed operations copy selected skills into a managed directory.
It calls each complete, retained copy a **package**. This is
a directory of skill files and installation metadata, not a Ruby gem or npm
package. For example, a `shaka` package contains `skills/shaka/SKILL.md`, its
references, scripts, Ruby helper, and configuration.

The code in this directory handles four parts of that installation:

- `Package` builds a temporary copy, checks that it matches the source, then
  renames it into the managed directory. Copied files belong to the installing
  account. It removes group and world write bits from copied files and
  directories; the content hash records those copied modes. Earlier packages
  remain for rollback.
- `Display` writes Codex menu metadata with the package's version and short
  revision, or a development content hash. It preserves other UI and invocation
  settings. Source identity keeps `content_sha256` for the source files and adds
  `package_content_sha256` for the final labeled copy. Both participate in its
  existing package-ID formula, so older doctor readers can identify the copy.
  Older installers cannot verify or roll back labeled packages; use the updated
  installer. Updated verification falls back to the original source hash for
  packages without the new field.
- `Links` points the coding agent's skill link, such as
  `~/.agents/skills/shaka`, at the finished package. “Switch” means replacing
  that link. An “owned host link” is an existing skill link whose target matches
  this Shaka source or the expected managed package path; the installer leaves
  unrelated destinations alone. This path check does not prove who created a
  package.
- `Refusal` words each installer refusal as the state, where it was found, and
  one next command, or the decision a person must make first. A link's owner is
  read from the install record in the checkout the link points into.
- `Source` records the copied files' Git revision when the source is the
  repository root, selected files and directories match the tracked tree,
  selected paths have clean Git status, raw file bytes and executable modes
  match `HEAD`, and no selected file is world-writable. Otherwise, it records a
  development installation with a content hash and, when available, a base revision.
- `Status` answers `install --status` without writing or fetching. `StatusInventory`
  finds links, records, and trials; `StatusCheckout`, `StatusLinks`, and
  `StatusUnsupported` turn what they find into findings; `StatusStates` orders them so
  the first one is the state to fix first. State IDs match the install-state
  matrix in [#683](https://github.com/shakacode/shaka/issues/683).
- `Version` reads the Shaka product version from `skills/shaka/lib/shaka/version.rb`
  without running that file. It does not read a repository workflow setting.

After a managed installation, the agent uses the retained copy through its skill link. The
original source checkout can be removed without breaking that installed skill.
