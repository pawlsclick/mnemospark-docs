# Cursor Dev: Docs — release ops (ops/release-planning-and-ops.md)

**ID:** cursor-dev-25  
**Repo:** mnemospark-docs

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark-docs. Documentation and feature specs live here. Do **not** open, clone, or require access to mnemospark or mnemospark-backend. The spec for this feature is at `features_cursor_dev/cursor-dev-25-docs-release-ops.md` when run from mnemospark-docs.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Create [ops/release-planning-and-ops.md](ops/release-planning-and-ops.md) with:

- **Initial setup** — ordered list: (1) npm account and token for publish; (2) GitHub repo NPM_TOKEN and any release permissions; (3) run cursor-dev-24 in mnemospark to add workflow + versioning; (4) create first release (version 0.1.0, tag `v0.1.0`, push tag, verify GitHub Release and npm).
- **Ongoing release management** — ordered list: (1) bump version in package.json (and CHANGELOG); (2) commit and push to main; (3) create and push tag `v<version>`; (4) workflow creates GitHub Release and publishes to npm; (5) verify release and npm; (6) optional: announce.

## References

- Plan: Versioning and releases (npm + GitHub) — §2 Release ops doc

## Cloud Agent

- **Install (idempotent):** None (markdown only).
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] File exists at `ops/release-planning-and-ops.md`.
  - [ ] Initial setup list is ordered and covers: npm token, NPM_TOKEN secret, cursor-dev-24, first release (0.1.0 / v0.1.0).
  - [ ] Ongoing release management list is ordered and covers: bump version + CHANGELOG, sync openclaw.plugin.json if needed, commit/push, tag/push, verify workflow and npm, optional announce.
  - [ ] No code changes in mnemospark repo.

## Task string (optional)

Work only in this repo (mnemospark-docs). Create ops/release-planning-and-ops.md with ordered lists for initial setup and ongoing release management as specified in Scope. Acceptance: [ ] file at ops/; [ ] initial setup list; [ ] ongoing list; [ ] no mnemospark code changes.
