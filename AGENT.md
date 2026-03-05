# Agent / CI checks

Before submitting changes, run:

```bash
forge fmt --check
```

If the check fails, run `forge fmt` (no `--check`) to format the code, then re-run `forge fmt --check` to confirm.

## Daily release

If there are changes to ship, do exactly one release per day. Before committing:

1. **Decide bump type** — patch (0.0.x) for fixes and small tweaks; minor (0.x.0) for new features or new ERCs; major (x.0.0) for breaking changes.
2. **Prepare release** — Bump `version` in `package.json`, update the `> vX.Y.Z` line in `README.md`, and add a new `## [X.Y.Z] — YYYY-MM-DD` section at the top of `CHANGELOG.md` with the changes for this release.
3. **One release per day** — Do not create more than one version in a single day; batch the day’s work into that single release.
