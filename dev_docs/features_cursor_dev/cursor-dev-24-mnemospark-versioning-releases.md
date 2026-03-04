# Cursor Dev: mnemospark versioning and releases (npm + GitHub)

**ID:** cursor-dev-24  
**Repo:** mnemospark

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark (OpenClaw plugin/client). Do **not** open, clone, or require access to mnemospark-backend or mnemospark-docs; all code and references are in this repo and `.company/`. The spec for this feature is at `.company/features_cursor_dev/cursor-dev-24-mnemospark-versioning-releases.md`.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Depends on cursor-dev-25 (release ops doc exists in mnemospark-docs). Implement versioning, CHANGELOG, plugin version sync, GitHub + npm release workflow, and `mnemospark update` / `mnemospark check-update` subcommands.

1. **Version** — In [package.json](package.json) set `"version": "0.1.0"`.
2. **CHANGELOG** — Add `CHANGELOG.md` at repo root (e.g. [Keep a Changelog](https://keepachangelog.com/) format). 0.1.0 is the initial release; there is no existing history. Initial entry for 0.1.0 (e.g. "Initial release"). Document in release ops that each release should update CHANGELOG.
3. **openclaw.plugin.json version** — Add a `"version"` field to [openclaw.plugin.json](openclaw.plugin.json). Keep it in sync with package.json: either a small script (e.g. `scripts/sync-plugin-version.js`) run in `prepare` or pre-build, or a note in release ops to update both when cutting a release. Prefer single source (package.json) with script sync so version cannot drift.
4. **GitHub Release workflow** — New workflow in `.github/workflows/release.yml` (or similar):
   - **Trigger:** Push of tag `v*.*.*` (e.g. `v0.1.0`).
   - **Steps:** Checkout, setup Node 20, `npm ci`, `npm run build`, run tests (or reuse CI job shape). Then: create GitHub Release for that tag; run `npm pack` and upload the `.tgz` as a release asset; run `npm publish` (use `NPM_TOKEN` secret). Protect publish with a check that the tag matches `package.json` version (e.g. tag `v0.1.0` ↔ version `0.1.0`).
5. **mnemospark update and check-update subcommands** — In [src/cli.ts](src/cli.ts) add two subcommands: `mnemospark update` and `mnemospark check-update`. Both fetch latest version from npm registry (`https://registry.npmjs.org/mnemospark/latest` or `npm view mnemospark version`) and compare with current `VERSION`. **check-update:** print whether an update is available and the latest version; if current is latest, print "You are on the latest version." **update:** if newer, run `npm install mnemospark@latest` in the appropriate context (global: `npm root -g` parent, or document that user runs from project) or print clear instructions; if no update, print "You are on the latest version."

## References

- [package.json](package.json), [openclaw.plugin.json](openclaw.plugin.json), [.github/workflows/ci.yml](.github/workflows/ci.yml), [src/version.ts](src/version.ts), [src/cli.ts](src/cli.ts)
- Release ops: [ops/release-planning-and-ops.md](https://github.com/pawlsclick/mnemospark-docs/blob/main/ops/release-planning-and-ops.md) (in docs repo)

## Cloud Agent

- **Install (idempotent):** `npm install`
- **Start (if needed):** None.
- **Secrets:** `NPM_TOKEN` for npm publish in the release workflow (GitHub Actions secret; not needed for local dev).
- **Acceptance criteria (checkboxes):**
  - [ ] package.json version is "0.1.0".
  - [ ] CHANGELOG.md exists with 0.1.0 entry (initial release, no prior history).
  - [ ] openclaw.plugin.json has "version" and stays in sync with package.json (script or documented step).
  - [ ] Pushing tag v0.1.0 triggers workflow: GitHub Release created with tarball asset, npm publish succeeds; tag must match package.json version.
  - [ ] `mnemospark check-update` prints latest version and whether update available; "You are on the latest version." when current.
  - [ ] `mnemospark update` installs or prints instructions when newer version exists; "You are on the latest version." when current.
  - [ ] Lint and build pass.

## Task string (optional)

Work only in this repo (mnemospark). Implement versioning and releases: set version 0.1.0, add CHANGELOG.md (initial release), add version to openclaw.plugin.json with sync from package.json, add .github/workflows/release.yml (tag v* → build, GitHub Release + tarball, npm publish with tag/version check), add mnemospark update and check-update subcommands (npm registry check, compare with VERSION, check-update prints status, update installs or instructions). Acceptance: [ ] version 0.1.0; [ ] CHANGELOG; [ ] plugin version sync; [ ] release workflow; [ ] update/check-update; [ ] lint/build.
