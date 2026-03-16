# Cursor Dev: Client JSONL Observability and Friendly-Name Manifest

**ID:** cursor-dev-42  
**Repo:** mnemospark

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is **mnemospark**. Do not use other repos. References: `cursor-dev-41` outputs and this file.

## Scope

Depends on **cursor-dev-41**.

Add structured JSONL observability for client-side operations and introduce a friendly-name manifest layer for human backup/restore UX.

Deliverables:
- `~/.openclaw/mnemospark/events.jsonl` append-only event stream.
- `~/.openclaw/mnemospark/manifest.jsonl` mapping for human-friendly names:
  - `friendly_name`, `object_id`, `object_key`, `quote_id`, `sha256`, `created_at`, optional tags.
- Optional client flags:
  - `--name` (backup/upload)
  - `--name` + `--latest|--at` (download/restore resolution)
- Event schema contract with consistent keys:
  - `ts`, `event_type`, `operation_id`, `wallet_address`, `object_id`, `object_key`, `quote_id`, `status`, `details`.
- Log rotation policy (size or date) with safe rollover.

## References

- `mnemospark-docs/ops/mnemospark-implementation-order-sqlite-jsonl-subagent-skill.md`
- `cursor-dev-41-client-sqlite-datastore-foundation.md`

## Agent

- **Install (idempotent):** `npm ci`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] Client emits JSONL events for all core operations.
  - [ ] Friendly-name manifest is written and queryable.
  - [ ] Name-to-object resolution supports duplicate handling (`--latest` or explicit selector).
  - [ ] Event keys are stable and documented in code comments/tests.
  - [ ] Rotation mechanism implemented and tested.
  - [ ] Branch from `main`, open PR.

## Task string (optional)

Implement JSONL observability and friendly-name manifest for mnemospark client on top of SQLite foundation. Include stable schema, rotation, and tests.


## Decision constraints
- Retention policy required: rotate JSONL at 10 MB, keep latest 10 files, gzip rotated files.
- Friendly names are optional inputs but default user-facing output must prefer friendly names when present.
