# Contributing

For a published guide, update `docs/sidebars.json` in the same PR. The docs site
syncs this navigation with the content; `bin/check-docs-navigation` rejects pages
missing from the sidebar and entries pointing to deleted pages. It also rejects
relative links and heading anchors in `docs/` and `skills/` that do not resolve,
and `shakacode/shaka` GitHub links to missing `docs/` pages or anchors anywhere
under `skills/`, including code. Site-only pages and the global header/footer
remain in the site repository.

Start with [developing Shaka](contributing/development.md) for local setup and
checks. Read [AGENTS.md](https://github.com/shakacode/shaka/blob/main/AGENTS.md) for repository constraints.

The [contributor index](contributing/README.md) covers implementation, packaging,
releases, and [evaluating changes](contributing/evaluating-changes.md).
[Development records](https://github.com/shakacode/shaka/blob/main/internal/README.md) hold requirements,
experiments, and dated adoption evidence.

For installing and using Shaka, see the [product documentation](docs/README.md).
