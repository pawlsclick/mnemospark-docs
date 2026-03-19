# Cursor Dev: Explicit subagent orchestration interfaces for mnemospark async operations

**ID:** cursor-dev-47  
**Repo:** mnemospark  
**Date:** 2026-03-19  
**Revision:** rev 2  

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is **mnemospark**. This repo contains the plugin, command parser/handlers, SQLite datastore integration, and JSONL observability paths for cloud operations. 


## Scope

Implement by adding a real OpenClaw subagent orchestration path for long-running client operations while preserving existing SQLite + JSONL tracking.


Required behavior:

1. Add a **subagent orchestration mode** for long-running operations (`backup`, `upload`, `download`).
2. Main command handler must return quickly with operation ID and orchestration metadata.
3. Use **one operation lifecycle** in existing `operations` table (no parallel tracker table).
4. Emit lifecycle/progress/terminal events to existing JSONL streams (`events.jsonl`, `proxy-events.jsonl`) and user-facing status messages.
5. Implement explicit cancel and timeout outcomes, visible in SQLite + JSONL.

## Diagrams

```mermaid
sequenceDiagram
  autonumber
  participant User
  participant Main as Main Agent (/mnemospark_cloud)
  participant DB as SQLite operations
  participant SA as OpenClaw Subagent Session
  participant Proxy as mnemospark proxy
  participant Backend as mnemospark backend

  User->>Main: /mnemospark_cloud upload ... --async --orchestrator subagent
  Main->>DB: upsertOperation(status=started)
  Main->>Main: spawn subagent with task envelope
  Main-->>User: operation-id + subagent-session + status command

  SA->>Proxy: execute sync upload flow
  Proxy->>Backend: settle/upload/confirm
  SA->>DB: upsertOperation(status=running/succeeded|failed|cancelled|timed_out)
  SA->>Main: emit progress + terminal update
  Main-->>User: final summary (or user polls op-status)
```

## Exact interfaces

### 1) Command interface additions (mnemospark cloud)

Canonical slash command name for native surfaces is `/mnemospark_cloud` (underscore).

Add optional flags for long-running commands:

- `--orchestrator <mode>` where mode in `{inline, subagent}` (default remains current behavior for backward compatibility; for `--async`, default should become `subagent` once stable).
- `--timeout-seconds <n>` optional per-operation timeout (subagent mode).
- `--cancel` for `op-status` command path (see op-status extension below).

Command examples:

- `/mnemospark_cloud upload ... --async --orchestrator subagent`
- `/mnemospark_cloud download ... --async --orchestrator subagent --timeout-seconds 900`
- `/mnemospark_cloud op-status --operation-id <id>`
- `/mnemospark_cloud op-status --operation-id <id> --cancel`

### 2) Subagent task envelope contract

Define a serialized handoff payload (TypeScript type + JSON shape):

```ts
type MnemosparkSubagentTaskV1 = {
  schema: "mnemospark.subagent-task.v1";
  operationId: string;
  traceId: string;
  command: "upload" | "download" | "restore";
  args: string; // sync command args (no --async)
  timeoutSeconds?: number;
  requestedBy: {
    pluginCommand: "mnemospark_cloud";
    chatId?: string;
    senderId?: string;
  };
};
```

Rules:
- `operationId` and `traceId` are created by main handler and reused through completion.
- Subagent executes sync path using forced operation/trace context.
- No extra lifecycle table; write status updates to existing `operations` row.

### 3) SQLite operation status contract (reuse existing table)

Status values used by orchestration path:
- `started`
- `running`
- terminal: `succeeded | failed | cancelled | timed_out`

Error codes for terminal failures:
- `ASYNC_FAILED`
- `ASYNC_EXCEPTION`
- `ASYNC_CANCELLED`
- `ASYNC_TIMEOUT`
- `ASYNC_DISPATCH_FAILED`

### 4) JSONL event contract additions (events.jsonl)

Emit these event types:
- `operation.dispatched`
- `operation.progress`
- `operation.cancel.requested`
- `operation.cancelled`
- `operation.timed_out`
- `operation.completed`

Required keys in each event payload:
- `operation_id`
- `trace_id`
- `event_type`
- `status`
- `ts`
- plus context fields (`wallet_address`, `object_id`, `object_key`, `quote_id`) when available.

### 5) op-status response extension

`op-status` output must include (when present):
- `operation-id`
- `type`
- `status`
- `started-at`
- `finished-at`
- `orchestrator: subagent|inline`
- `subagent-session-id`
- `timeout-seconds`
- `error-code` / `error-message`

### 6) Cancellation contract

- `op-status --operation-id <id> --cancel` requests cancellation.
- If subagent session exists, signal cancel and transition:
  - interim: `running` + cancel requested event
  - terminal: `cancelled` with `ASYNC_CANCELLED`
- Must be idempotent (repeated cancel requests do not corrupt state).

## References

- OpenClaw subagents docs | raw: `https://docs.openclaw.ai/tools/subagents`

## Agent

- **Install (idempotent):** `npm ci`
- **Start (if needed):** None.
- **Secrets:** None beyond existing runtime config.
- **Acceptance criteria (checkboxes):**
  - [ ] `upload` and `download` support `--async --orchestrator subagent` and return quickly with operation ID.
  - [ ] Main handler persists operation row in `operations` and records dispatch metadata.
  - [ ] Subagent executes sync command path with forced operation/trace IDs.
  - [ ] Progress and terminal events are emitted to JSONL with required correlation fields.
  - [ ] `op-status` shows orchestrator/session/timeout context and terminal outcomes.
  - [ ] Cancellation path works and records `cancelled` + `ASYNC_CANCELLED` semantics.
  - [ ] Timeout path works and records `timed_out` + `ASYNC_TIMEOUT` semantics.
  - [ ] Tests cover dispatch, success, failure, cancel, and timeout transitions.
  - [ ] Branch from `main`, open PR.
