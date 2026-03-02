# mnemospark release planning and ops

Ordered steps for initial setup and ongoing release management (npm + GitHub).

## Initial setup

1. Ensure you have an npm account and (if not already) create an npm access token for publishing the `mnemospark` package.
2. In the mnemospark GitHub repo, add `NPM_TOKEN` as a secret (Settings → Secrets and variables → Actions). Use the npm token that has publish rights.
3. Complete the mnemospark versioning feature (cursor-dev-24): version 0.1.0, CHANGELOG (initial release, no prior history), openclaw.plugin.json version sync, release workflow, and `mnemospark update` / `mnemospark check-update` subcommands.
4. Create the first release: ensure `package.json` version is `0.1.0` and CHANGELOG has the initial 0.1.0 entry; commit and push to main; create tag `v0.1.0` and push it; confirm the release workflow runs, a GitHub Release is created with the tarball asset, and the package is published to npm.

## Ongoing release management

1. Bump `version` in `package.json` (semver). Update `CHANGELOG.md` with the new version and changes.
2. If using a sync script for openclaw.plugin.json, run it (or ensure `prepare`/build does); otherwise update `openclaw.plugin.json` version to match.
3. Commit and push to main (e.g. "Release 0.2.0").
4. Create tag `v<version>` (e.g. `v0.2.0`) and push: `git tag v0.2.0 && git push origin v0.2.0`.
5. Verify the GitHub Action runs: GitHub Release is created with the packed tarball and npm publish succeeds.
6. (Optional) Announce the release (e.g. docs, changelog link).
