# mnemospark JSONL Streaming Troubleshooting

## Quick triage checklist
1. Verify JSONL files exist under `~/.openclaw/mnemospark/`
2. Check write permissions on directory
3. Tail live events while reproducing issue
4. Correlate by `operation_id` / `quote_id` / `object_id`
5. Check rotated `.gz` archives if event not in current file

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
If missing, install (Ubuntu example):
```bash
sudo apt-get update && sudo apt-get install -y sqlite3 jq coreutils grep gawk sed gzip
```
Fail fast if tools unavailable.

## Files and purpose
- `events.jsonl`: client-side operation events
- `manifest.jsonl`: friendly-name audit mappings
- `proxy-events.jsonl`: proxy-side correlated events (`trace_id`, `operation_id`, terminal states)

## Command cookbook
Set base path:
```bash
LOGDIR="$HOME/.openclaw/mnemospark"
```

Live tail all streams:
```bash
tail -F "$LOGDIR/events.jsonl" "$LOGDIR/manifest.jsonl" "$LOGDIR/proxy-events.jsonl"
```

Filter by operation id:
```bash
OP="<operation-id>"
grep -h "$OP" "$LOGDIR"/*.jsonl | jq -c .
```

Filter by quote/object:
```bash
Q="<quote-id>"
O="<object-id>"
grep -h "$Q\|$O" "$LOGDIR"/*.jsonl | jq -c .
```

Show terminal proxy events:
```bash
jq -c 'select(.event_type|test("terminal\\.(success|failure)"))' "$LOGDIR/proxy-events.jsonl"
```

Inspect rotated gzip archives:
```bash
zcat "$LOGDIR"/events.jsonl.*.gz | tail -n 200
zcat "$LOGDIR"/proxy-events.jsonl.*.gz | tail -n 200
```

## Common failure signatures
- **No JSONL output at all**
  - Root cause: path/permission issue or process not writing.
  - Next action: verify directory ownership and process user.

- **Missing terminal events in proxy stream**
  - Root cause: request exited before terminal emit path.
  - Next action: correlate with proxy logs + HTTP status path.

- **Event exists in SQLite but not JSONL**
  - Root cause: best-effort logging skipped due to file IO issue.
  - Next action: treat DB as source of truth, fix filesystem issue.

## What to collect before opening an issue
- Last 200 lines from each JSONL stream
- Matching rotated `.gz` excerpts if relevant
- Correlation IDs (`operation_id`, `trace_id`, `quote_id`)
- Host path permissions (`ls -la ~/.openclaw/mnemospark`)
