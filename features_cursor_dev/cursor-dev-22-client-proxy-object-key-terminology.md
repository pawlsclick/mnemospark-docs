# Cursor Dev: Client and proxy — standardize on object-key in user-facing text

**ID:** cursor-dev-22  
**Repo:** mnemospark

**Workspace for Cloud Agent:** Work only in **this repo** (the repo you were started in). This repo is mnemospark. Client and proxy code live here. Do **not** open, clone, or require access to mnemospark-backend or any other repository; all code and references are in this repo and `.company/`. The spec for this feature is at `.company/features_cursor_dev/cursor-dev-22-client-proxy-object-key-terminology.md`.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Align user-facing terminology with the docs and backend: use **object-key** (not s3-key) when describing the storage key placeholder in help text and messages. No API or flag renames: the flag remains `--object-key`; only the placeholder name in help and any literal "s3-key" strings change to "object-key".

1. **Client (cloud-command.ts)**
   - In the help text that lists ls, download, and delete (e.g. the bullets showing command syntax), replace the placeholder `<s3-key>` with `<object-key>` so the examples read:
     - `/cloud ls --wallet-address <addr> --object-key <object-key>`
     - `/cloud download --wallet-address <addr> --object-key <object-key>`
     - `/cloud delete --wallet-address <addr> --object-key <object-key>`
   - Ensure any other user-facing string that refers to "s3-key" or "<s3-key>" is updated to "object-key" / "<object-key>" (e.g. argument descriptions if they exist in the client).

2. **Proxy (proxy.ts)**
   - Confirm no user-facing strings use "s3-key". The proxy already uses `object_key` in API and error messages ("Missing required fields: wallet_address, object_key"). If any response or log uses "s3-key", replace with "object-key"; otherwise no change.

3. **Tests**
   - Update any test that asserts on help text or user messages containing "s3-key" so they expect "object-key" instead. Do not change test logic for API fields (object_key stays).

Behavior and API contracts are unchanged; only terminology in help and user-facing copy is updated.

## Handoff

After completing the changes: **open a new branch** (e.g. from `main`), **commit** all changes, **push** the branch, and **create a PR** for review. Do not commit directly to `main`/`master`.

## References

- [mnemospark_full_workflow.md](../mnemospark_full_workflow.md) — workflow (object-key as single term)
- [cursor-dev-21-docs-object-key-terminology.md](cursor-dev-21-docs-object-key-terminology.md) — docs alignment (run first or in parallel)

## Cloud Agent

- **Install (idempotent):** `npm install`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] cloud-command.ts: help bullets for ls, download, delete use `<object-key>` instead of `<s3-key>`.
  - [ ] cloud-command.ts: no remaining user-facing "<s3-key>" or "s3-key" for the storage key.
  - [ ] proxy.ts: no user-facing "s3-key"; keep object_key in API/errors (no change if already correct).
  - [ ] Tests: any assertion on help or messages that referenced s3-key now expects object-key; tests pass.
  - [ ] Lint and build pass.
  - [ ] Handoff: new branch opened, changes committed and pushed, PR created.

## Task string (optional)

Work only in this repo (mnemospark). Replace <s3-key> with <object-key> in client help text for ls, download, delete. Check proxy for any s3-key strings; keep object_key in API. Update tests that assert on s3-key in help or messages. Acceptance: [ ] help uses object-key; [ ] proxy checked; [ ] tests updated and pass; [ ] lint/build pass.
