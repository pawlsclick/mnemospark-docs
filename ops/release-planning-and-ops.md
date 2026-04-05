# mnemospark release planning and ops

How the **mnemospark** npm package and GitHub releases are cut and published. Version **names** follow the same calendar-oriented style as [OpenClaw’s release policy](https://docs.openclaw.ai/reference/RELEASING); the repo still uses valid **semver** strings on npm.

## Version and tag naming

| Kind | Version in `package.json` | Git tag |
|------|---------------------------|---------|
| Stable | `YYYY.M.D` (month and day are not zero-padded) | `vYYYY.M.D` |
| Same-day correction | `YYYY.M.D-N` (semver prerelease segment) | `vYYYY.M.D-N` |
| Beta (optional) | `YYYY.M.D-beta.N` | `vYYYY.M.D-beta.N` |

Day-to-day automation uses **Release Please** with **`versioning: always-bump-patch`** so conventional **`feat:`** commits do not perform a semver *minor* bump (which would turn `2026.4.5` into `2026.5.0` and break the “day as patch” shape). When the **next public version should match a new calendar date** (not only the next patch digit), use Release Please’s **`Release-As: YYYY.M.D`** in a commit message footer, or adjust the version on the release PR before merge.

## Repository automation (mnemospark)

### 1. Release PR (`Release PR` workflow)

- **Trigger:** push to `main`, or manual `workflow_dispatch`.
- **Action:** [release-please-action v4](https://github.com/googleapis/release-please-action) reads [`release-please-config.json`](https://github.com/pawlsclick/mnemospark/blob/main/release-please-config.json) and [`.release-please-manifest.json`](https://github.com/pawlsclick/mnemospark/blob/main/.release-please-manifest.json).
- **Output:** an autorelease PR that bumps `package.json`, `CHANGELOG.md`, manifest, and (via `extra-files`) `openclaw.plugin.json` when needed.

**Token note:** the default `GITHUB_TOKEN` cannot trigger other workflows when it creates the release. Set repository secret **`RELEASE_PLEASE_TOKEN`** to a fine-grained or classic PAT with **`contents:write`** and **`pull_requests:write`** on this repo, and point the workflow at it (see comments in [`.github/workflows/release-pr.yml`](https://github.com/pawlsclick/mnemospark/blob/main/.github/workflows/release-pr.yml)). If unset, the workflow falls back to `github.token` (release may not chain to Publish).

### 2. Merge the release PR

- Merging opens/creates the **GitHub Release** and tag (e.g. `v2026.4.5`).
- Do **not** rely on a separate manual tag push for the normal train unless you know you need it—duplicate events have caused **double publish** in the past.

### 3. Publish (`Publish` workflow)

- **Trigger:** `release` **published**, or **`workflow_dispatch`** with input **`publish_ref`** (a tag such as `v2026.4.5`).
- **Steps:** checkout ref → verify tag matches `package.json` version → lint, test, build → `npm publish --provenance --access public`.
- **npm auth:** [`NODE_AUTH_TOKEN`](https://github.com/pawlsclick/mnemospark/blob/main/.github/workflows/publish.yml) from secret **`NPM_MNEMOSPARK`** (configure in **Settings → Secrets and variables → Actions**).

### Maintainer checklist

1. Land work on `main` with [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, etc.).
2. Let Release Please open (or update) the release PR; resolve conflicts if any.
3. Merge the release PR when ready.
4. Confirm the **Publish** workflow completes and **`mnemospark@<version>`** appears on the npm registry.
5. Optional: announce (changelog link, docs).

## Initial / one-time setup

1. **npm:** org access and an automation token with publish rights for package **`mnemospark`**.
2. **GitHub Actions secrets (mnemospark repo):**
   - **`NPM_MNEMOSPARK`** — npm token for `npm publish`.
   - **`RELEASE_PLEASE_TOKEN`** — PAT for Release Please if you need downstream workflows to run when the release is created.
3. **Local / CI:** Node **22** matches the project engines and workflows.

## Relationship to docs

Runtime behavior and env defaults (for example the default backend base URL) are documented in **`meta_docs/`** in this repo; update those specs when release or client behavior changes (see [`meta_docs/README.md`](../meta_docs/README.md)).
