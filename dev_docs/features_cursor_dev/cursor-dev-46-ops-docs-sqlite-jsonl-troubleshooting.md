# Cursor Dev: Ops Docs for SQLite Queries and JSONL Streaming Troubleshooting

**ID:** cursor-dev-46  
**Repo:** mnemospark-docs

**Workspace for Agent:** Work only in **mnemospark-docs**. Documentation output must be under `ops/`.

## Scope

Depends on **cursor-dev-41**, **cursor-dev-42**, **cursor-dev-43**, **cursor-dev-44**, **cursor-dev-45**.

Document practical troubleshooting and observability procedures for operators.
Include transition-era guidance where SQLite/JSONL is primary but legacy `object.log`/`crontab.txt` compatibility paths may still be encountered.

Required output docs under `ops/`:
- `ops/mnemospark-sqlite-queries.md`
- `ops/mnemospark-jsonl-streaming.md`
- `ops/mnemospark-async-ops-troubleshooting.md`

Each doc must include:
- quick triage checklist
- command cookbook (sqlite3 queries, jq/tail examples)
- common failure signatures + likely root cause + next action
- “what to collect before opening issue” section

## References

- `mnemospark-docs/ops/mnemospark-implementation-order-sqlite-jsonl-subagent-skill.md`
- Prior cursor-dev outputs (41–45)

## Agent

- **Install (idempotent):** None.
- **Start (if needed):** None.
- **Secrets:** None.
- **Acceptance criteria (checkboxes):**
  - [ ] All three ops docs created in `ops/`.
  - [ ] All three ops docs created in `ops/`.
- [ ] SQLite query examples cover objects/payments/cron_jobs/operations tables.
- [ ] SQLite query examples include `friendly_names` table (Option 2 from cursor-dev-42) and name-resolution diagnostics.
- [ ] JSONL examples cover filtering by quote_id/object_id/operation_id.
- [ ] JSONL docs explicitly cover `events.jsonl`, `manifest.jsonl`, and `proxy-events.jsonl` (including best-effort logging, rotation, and terminal success/failure event interpretation from cursor-dev-43).
- [ ] Async orchestration runbook includes progress, timeout, retry, and stuck-task procedures.
- [ ] Async runbook includes `/mnemospark-cloud op-status --operation-id <id>` troubleshooting and SQLite-unavailable fallback behavior (`Operation not found` semantics).
- [ ] Branch from `main`, open PR.

## Task string (optional)

Write operator-focused docs for SQLite querying and JSONL stream troubleshooting in mnemospark-docs/ops, aligned to async subagent execution model.


## Output produced in this docs repo
- `ops/mnemospark-sqlite-queries.md`
- `ops/mnemospark-jsonl-streaming.md`
- `ops/mnemospark-async-ops-troubleshooting.md`

## Decision constraints
- Include a mandatory "Required Tools" section listing: sqlite3, jq, tail, grep, awk, sed, gzip/zcat.
- Include install-time validation guidance for these tools (auto-install where possible, fail-fast otherwise).
