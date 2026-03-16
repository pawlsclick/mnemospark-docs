# Cursor Dev: Client SQLite Datastore Foundation

**ID:** cursor-dev-41  
**Repo:** mnemospark

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is **mnemospark**. Client/plugin runtime lives here. Do **not** clone, or require access to any other repository; all code and references are in this file. References: OpenClaw plugin command paths and local storage under `~/.openclaw/mnemospark/`.

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

Implement a SQLite-based client datastore to replace ad-hoc file state for operational records while preserving backward compatibility.

Deliverables:
- New client DB path (default): `~/.openclaw/mnemospark/state.db`
- Migration bootstrap that can read existing `object.log` and `crontab.txt` and seed normalized tables.
- Schema v1 with explicit migrations table.
- Read/write abstraction module used by backup/quote/upload/ls/download/delete and cron registration paths.
- Feature flag or safe fallback path if DB unavailable.

Schema v1 minimum:
- `objects` (object_id, object_key, wallet_address, quote_id, provider, bucket_name, region, sha256, status, created_at, updated_at)
- `payments` (quote_id, wallet_address, trans_id, amount, network, status, settled_at)
- `cron_jobs` (cron_id, object_id, object_key, quote_id, schedule, command, status, created_at, updated_at)
- `operations` (operation_id, type, object_id, quote_id, status, error_code, error_message, started_at, finished_at)
- `schema_migrations` (version, applied_at)

## References

- `mnemospark-docs/ops/mnemospark-implementation-order-sqlite-jsonl-subagent-skill.md`
- Existing client logs/state paths currently in use under `~/.openclaw/mnemospark/`
- SQLite best practices: transactions, constraints, indexes

## Agent

- **Install (idempotent):** `npm ci`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] SQLite DB initializes on demand at `~/.openclaw/mnemospark/state.db`.
  - [ ] Schema v1 + migration tracking implemented.
  - [ ] Legacy state import path exists for `object.log` and `crontab.txt`.
  - [ ] Existing command outcomes still work with no regressions.
  - [ ] Unit tests cover initialization, insert/update/query, and migration bootstrap.
  - [ ] Branch from `main`, open PR (no direct commit to `main`).

## Task string (optional)

Work only in mnemospark repo. Implement SQLite datastore foundation with migration-safe schema and legacy import from current logs. Preserve existing behavior, add tests, and open PR from a new branch.


## Decision constraints
- Do not implement legacy migration/import from `object.log` or `crontab.txt` in this run.
- Initialize clean SQLite schema only.
