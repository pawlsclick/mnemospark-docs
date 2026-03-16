# Cursor Dev: OpenClaw Subagent Orchestration for mnemospark Long-Running Tasks

**ID:** cursor-dev-44  
**Repo:** mnemospark

**Workspace for Agent:** Work only in **mnemospark**. This implementation should integrate with OpenClaw subagent tool semantics without changing other repos in this run.

## Scope

Depends on **cursor-dev-41**, **cursor-dev-42** (merged at `47389d1bac0397cc60ba13018f6f3ebce52f6ac1`), and **cursor-dev-43** (merged at `89cbf6745c7af893cf4f4679e4638086419f2a5f`). This run must reuse the existing SQLite schema (`operations` plus Option 2 `friendly_names`) and JSONL event model introduced in 42/43, not introduce parallel tracking structures.

Implement asynchronous mnemospark task execution model so the main OpenClaw agent delegates long-running mnemospark operations to a dedicated mnemospark agent/session and remains responsive.

Deliverables:
- Task handoff contract from main agent -> mnemospark agent.
- Async operation tracking in SQLite using the existing `operations` table from cursor-dev-41.
- Progress + terminal updates emitted to the JSONL streams defined in cursor-dev-42/43 (`events.jsonl`, `manifest.jsonl`, `proxy-events.jsonl`) and user-facing status messages.
- Reuse existing operation timestamp semantics from merged cursor-dev-41 (single operation lifecycle with clear started/finished transitions, no duplicate parallel trackers).
- Command behavior for long tasks (`upload`, `download`, potentially `restore`) should return quickly with operation ID and progress model.
- Failure semantics for cancellation/timeouts/retries.

## References

- OpenClaw subagents docs: https://docs.openclaw.ai/tools/subagents
- `mnemospark-docs/ops/mnemospark-implementation-order-sqlite-jsonl-subagent-skill.md`
- `cursor-dev-41`, `cursor-dev-42`

## Agent

- **Install (idempotent):** `npm ci`
- **Start (if needed):** None.
- **Secrets:** None beyond existing runtime config.
- **Acceptance criteria (checkboxes):**
  - [ ] Main agent can dispatch long mnemospark operations without blocking.
  - [ ] Operation IDs persist in SQLite and are queryable.
  - [ ] User gets progress and final outcome updates.
  - [ ] Retry/cancel outcomes are observable in JSONL + SQLite.
  - [ ] Tests include long-running mock execution and status transitions.
  - [ ] Branch from `main`, open PR.

## Task string (optional)

Implement async subagent orchestration flow for mnemospark long operations with SQLite-backed operation tracking and JSONL progress events.


## Decision constraints
- Use OpenClaw `subagent` runtime for async delegation (not ACP).
- Main agent should return quickly with operation ID and continue user interaction while mnemospark subagent executes.
