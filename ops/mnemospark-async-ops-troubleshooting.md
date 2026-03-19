# mnemospark Async Ops Troubleshooting

## Quick triage checklist
1. Confirm command was launched with `--async`
2. Capture returned `operation-id`
3. Check status via `/mnemospark_cloud op-status --operation-id <id>`
4. Query `operations` table for lifecycle
5. Correlate with `events.jsonl` + `proxy-events.jsonl`

## Required Tools
- `sqlite3`
- `jq`
- `tail`
- `grep`
- `awk`
- `sed`
- `gzip` / `zcat`

## Install-time validation guidance
```bash
command -v sqlite3 jq tail grep awk sed gzip zcat
```
Auto-install where possible (Ubuntu):
```bash
sudo apt-get update && sudo apt-get install -y sqlite3 jq coreutils grep gawk sed gzip
```
If missing and cannot install, fail fast.

## Runbook
### Start async operation
- Upload: `... upload ... --async`
- Download: `... download ... --async`

### Check progress
```bash
/mnemospark_cloud op-status --operation-id <id>
```

### DB verification
```bash
DB="$HOME/.openclaw/mnemospark/state.db"
sqlite3 "$DB" "SELECT operation_id,type,status,error_code,error_message,started_at,finished_at,updated_at FROM operations WHERE operation_id='<id>';"
```

### JSONL correlation
```bash
LOGDIR="$HOME/.openclaw/mnemospark"
grep -h "<id>" "$LOGDIR"/events.jsonl "$LOGDIR"/proxy-events.jsonl | jq -c .
```

## Failure signatures + actions
- **Stuck in `started` for too long**
  - Root cause: downstream call hung or background task crashed silently.
  - Action: inspect proxy terminal events; retry operation with fresh id.

- **`failed` + `ASYNC_FAILED`**
  - Root cause: underlying sync path returned error.
  - Action: use error message, run equivalent command synchronously for deeper error output.

- **`Operation not found: <id>`**
  - Root cause: SQLite unavailable (expected fallback) or op id typo.
  - Action: verify SQLite health and exact id; if SQLite disabled, rely on JSONL traces and rerun once DB restored.

- **Retry loops without success**
  - Root cause: unsettled payment, auth mismatch, or missing object key.
  - Action: verify wallet/quote/object integrity and proxy settle events.

## What to collect before opening an issue
- `operation-id`
- `op-status` output
- `operations` row dump
- Correlated JSONL slices from `events.jsonl` + `proxy-events.jsonl`
- Exact command and timestamp
- Environment flags (especially `MNEMOSPARK_DISABLE_SQLITE`)
