# mnemospark SQLite Queries (Operator Runbook)

## Quick triage checklist
1. Confirm DB exists: `~/.openclaw/mnemospark/state.db`
2. Check SQLite availability: `sqlite3 --version`
3. Validate schema/tables present (`objects`, `payments`, `cron_jobs`, `operations`, `friendly_names`)
4. Check recent failed operations in `operations`
5. Cross-check related JSONL events (`events.jsonl`, `proxy-events.jsonl`)

## Required Tools
- `sqlite3`
- `jq`
- `tail`
- `grep`
- `awk`
- `sed`
- `gzip` / `zcat`

## Install-time validation guidance
Run:
```bash
command -v sqlite3 jq tail grep awk sed gzip zcat
```
If a tool is missing, auto-install where possible:
- Debian/Ubuntu: `sudo apt-get update && sudo apt-get install -y sqlite3 jq coreutils grep gawk sed gzip`
If install is not possible, fail fast and stop triage until tools are present.

## Command cookbook
DB path:
```bash
DB="$HOME/.openclaw/mnemospark/state.db"
```

List tables:
```bash
sqlite3 "$DB" ".tables"
```

Recent objects:
```bash
sqlite3 "$DB" "SELECT object_id, object_key, wallet_address, quote_id, status, updated_at FROM objects ORDER BY updated_at DESC LIMIT 20;"
```

Recent payments:
```bash
sqlite3 "$DB" "SELECT quote_id, wallet_address, amount, status, settled_at, updated_at FROM payments ORDER BY updated_at DESC LIMIT 20;"
```

Active cron jobs:
```bash
sqlite3 "$DB" "SELECT cron_id, object_id, object_key, quote_id, schedule, status FROM cron_jobs WHERE status='active' ORDER BY updated_at DESC;"
```

Operation status lookup:
```bash
sqlite3 "$DB" "SELECT operation_id, type, status, error_code, error_message, started_at, finished_at, updated_at FROM operations ORDER BY updated_at DESC LIMIT 50;"
```

Friendly-name diagnostics:
```bash
sqlite3 "$DB" "SELECT friendly_name, object_id, object_key, quote_id, wallet_address, created_at, is_active FROM friendly_names ORDER BY created_at DESC LIMIT 50;"
```

Resolve a name (latest):
```bash
NAME="project-alpha"
WALLET="0x..."
sqlite3 "$DB" "SELECT friendly_name, object_id, object_key, quote_id, created_at FROM friendly_names WHERE wallet_address='$WALLET' AND friendly_name='$NAME' AND is_active=1 ORDER BY created_at DESC LIMIT 1;"
```

## Common failure signatures
- **`Operation not found: <id>`**
  - Likely root cause: SQLite unavailable/disabled or operation never persisted.
  - Next action: verify `MNEMOSPARK_DISABLE_SQLITE`, DB file existence, rerun with healthy SQLite.

- **Name ambiguity (multiple matches for `--name`)**
  - Likely root cause: same friendly name reused.
  - Next action: use `--latest` or `--at <timestamp>`.

- **Missing `friendly_names` table**
  - Likely root cause: migration drift.
  - Next action: verify running build includes cursor-dev-42 migration v2.

## What to collect before opening an issue
- Output of `sqlite3 "$DB" ".tables"`
- Relevant `operations` row(s)
- Relevant `friendly_names` row(s)
- Timestamp + command used
- App version / commit hash
