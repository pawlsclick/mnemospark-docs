# Cursor Dev: Client JSONL Observability + Friendly-Name Resolution

**ID:** cursor-dev-42  
**Repo:** mnemospark

**Workspace for Agent:** Work only in **mnemospark** repo. Do not use other repos. References: `cursor-dev-41` outputs and this file.

## Scope

Depends on **cursor-dev-41** (SQLite schema v1).

This run adds:
1. Structured JSONL observability
2. Friendly-name UX (`--name`) for slash commands
3. Client-side name resolution for `ls/download/delete`

### Important update (decision lock)
Friendly-name resolution must use **SQLite as source of truth** for query correctness.  
`manifest.jsonl` is kept as append-only audit/history for observability and troubleshooting.

SQLite schema update is required in this run to support reliable friendly-name resolution (Option 2: dedicated `friendly_names` table).

## Deliverables

- `~/.openclaw/mnemospark/events.jsonl` append-only event stream.
- `~/.openclaw/mnemospark/manifest.jsonl` append-only friendly-name audit stream.
- Friendly-name state/query implemented via SQLite (`~/.openclaw/mnemospark/state.db`) with a dedicated `friendly_names` table.
- Migration v2 (Option 2 schema) added:
  - `friendly_names` (`friendly_name_id`, `friendly_name`, `object_id`, `object_key`, `quote_id`, `wallet_address`, `created_at`, `updated_at`, `is_active`)
  - Required indexes: `idx_friendly_names_name`, `idx_friendly_names_object_id`, `idx_friendly_names_wallet`, `idx_friendly_names_created_at`
  - Name lookup rules should be deterministic for duplicate names (`--latest` / `--at`).
- Stable event schema keys:
  - `ts`, `event_type`, `operation_id`, `wallet_address`, `object_id`, `object_key`, `quote_id`, `status`, `details`
- JSONL rotation/retention:
  - rotate at 10 MB
  - keep latest 10 files
  - gzip rotated files

## Command contract (explicit)

Update `/mnemospark-cloud` help + parser behavior to support:

- `/mnemospark-cloud backup <file|directory> [--name <friendly-name>]`
  - If `--name` omitted, default to basename of `<file|directory>`.
  - This is where the human-facing label usually starts.

- `/mnemospark-cloud price-storage --wallet-address <addr> --object-id <id> --object-id-hash <hash> --gb <gb> --provider <provider> --region <region>`
  - No required `--name`.
  - May enrich output with friendly name when known client-side.

- `/mnemospark-cloud upload --quote-id <quote-id> --wallet-address <addr> --object-id <id> --object-id-hash <hash> [--name <friendly-name>]`
  - Optional `--name` updates/creates client-side mapping.

- `/mnemospark-cloud ls --wallet-address <addr> [--object-key <object-key> | --name <friendly-name>] [--latest | --at <timestamp>]`
- `/mnemospark-cloud download --wallet-address <addr> [--object-key <object-key> | --name <friendly-name>] [--latest | --at <timestamp>]`
- `/mnemospark-cloud delete --wallet-address <addr> [--object-key <object-key> | --name <friendly-name>] [--latest | --at <timestamp>]`

Resolution rules:
- `--object-key` and `--name` are mutually exclusive.
- If `--name` resolves to multiple objects and no selector is provided, return clear ambiguity error.
- `--latest` resolves to newest match.
- `--at` resolves by timestamp selector.
- Name resolution is client-side only (never required by backend API contract).

## References

- `mnemospark-docs/ops/mnemospark-implementation-order-sqlite-jsonl-subagent-skill.md`
- `cursor-dev-41-client-sqlite-datastore-foundation.md`

## Agent

- **Install (idempotent):** `npm ci`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] Client emits JSONL events for all core operations.
  - [ ] Friendly-name operations are persisted and queryable via SQLite (source of truth).
  - [ ] Includes migration v2 for dedicated `friendly_names` table.
  - [ ] `manifest.jsonl` records friendly-name history/audit entries.
  - [ ] Name-to-object resolution supports duplicate handling (`--latest` or `--at`).
  - [ ] `/mnemospark-cloud help` explicitly documents new `--name` command structure.
  - [ ] Event keys are stable and documented in code comments/tests.
  - [ ] Rotation mechanism implemented and tested (10 MB, keep 10, gzip).
  - [ ] Branch from `main`, open PR.

## Task string (optional)

Implement JSONL observability + friendly-name UX for mnemospark client on top of cursor-dev-41.
Use SQLite as source of truth for name resolution, keep manifest/events JSONL for audit/ops, and update slash-command contract/help text accordingly.

## Decision constraints

- Retention policy required: rotate JSONL at 10 MB, keep latest 10 files, gzip rotated files.
- Friendly names are optional inputs; user-facing output should prefer friendly name when present.
- Friendly-name query resolution must be SQLite-first (not JSONL parsing).
- Option 2 schema is required: add and migrate dedicated `friendly_names` table in SQLite.
- No backend API changes required for `--name`.
