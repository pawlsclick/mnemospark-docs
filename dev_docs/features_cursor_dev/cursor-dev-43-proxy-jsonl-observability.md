# Cursor Dev: Proxy JSONL Observability

**ID:** cursor-dev-43  
**Repo:** mnemospark

**Workspace for Agent:** Work only in **this repo**. This repo is **mnemospark**. No other repo access required.

## Scope

Depends on **cursor-dev-42** (including Option 2 `friendly_names` migration on top of cursor-dev-41). This run must not introduce new SQLite schema changes; it only adds proxy-side JSONL observability.

Add structured JSONL observability for the mnemospark proxy layer so long-running and retry-prone paths are traceable end-to-end.

Deliverables:
- Proxy event stream file: `~/.openclaw/mnemospark/proxy-events.jsonl`
- Correlation fields on every event:
  - `trace_id`, `operation_id`, `quote_id`, `wallet_address`, `object_id`, `object_key`
- Required event classes:
  - request received
  - payment settle call start/result
  - storage call start/result
  - retry decisions
  - terminal success/failure
- Compatibility with client events (`events.jsonl`) for joint troubleshooting.
  - Proxy events must be designed so they can be stitched with client `events.jsonl` using shared IDs (e.g., `operation_id`, `quote_id`, `wallet_address`, `object_id`, `object_key`).
  - Correlation should tolerate nullable identifiers (especially `quote_id`/`object_key`) and still emit usable traces.

## References

- `cursor-dev-42-client-jsonl-observability-and-manifest.md`
- Existing proxy logging in `src/proxy.ts`

## Agent

- **Install (idempotent):** `npm ci`
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] Proxy writes JSONL events with stable schema.
  - [ ] Correlation identifiers allow stitching client + proxy flows.
  - [ ] Retry/error paths explicitly logged with reason codes.
  - [ ] Unit tests cover schema and key event transitions.
  - [ ] Branch from `main`, open PR.

## Task string (optional)

Instrument mnemospark proxy with JSONL observability for settle/upload/download paths, including correlation IDs and retry semantics.


## Decision constraints
- Proxy JSONL retention must follow client policy (10 MB rotate, keep 10, gzip).
