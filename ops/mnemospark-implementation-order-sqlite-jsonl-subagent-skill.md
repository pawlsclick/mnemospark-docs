# mnemospark Implementation Order — SQLite + JSONL + Subagent + Skill

Date: 2026-03-16

This is a planning-only execution order. No code changes are included in this document.

## Objective

Implement (in phased order):
1. SQLite client datastore
2. JSONL observability for client + proxy
3. Main-agent → mnemospark-agent async orchestration for long tasks
4. mnemospark skill for operational knowledge/context
5. Ops docs for SQLite querying + JSONL streaming/troubleshooting in `mnemospark-docs/ops`

## Cursor-dev execution order (strict)

1. `cursor-dev-41-client-sqlite-datastore-foundation.md`
2. `cursor-dev-42-client-jsonl-observability-and-manifest.md` (depends on 41)
3. `cursor-dev-43-proxy-jsonl-observability.md` (depends on 42)
4. `cursor-dev-44-openclaw-subagent-orchestration-for-mnemospark.md` (depends on 41, 42)
5. `cursor-dev-45-mnemospark-skill-authoring.md` (depends on 44)
6. `cursor-dev-46-ops-docs-sqlite-jsonl-troubleshooting.md` (depends on 41–45)

## Repo mapping for each run

- 41: `mnemospark`
- 42: `mnemospark`
- 43: `mnemospark`
- 44: `mnemospark` (or OpenClaw integration layer if commands are hosted there)
- 45: `mnemospark-docs` (skill specs/docs + usage guides)
- 46: `mnemospark-docs`

## Why this order

- SQLite schema and migration strategy must exist first so all subsequent logging and orchestration references a stable state model.
- JSONL design should align to SQLite IDs and lifecycle states (avoid divergent observability models).
- Subagent orchestration should only be implemented after datastore + observability are in place, so progress and outcomes can be reported reliably.
- Skill authoring should follow actual command/state model decisions from implementation.
- Ops docs should be last, after interfaces and fields are finalized.

## Exit criteria for “phase complete”

- All 6 cursor-dev files merged via PRs (no direct main commits).
- End-to-end async run demonstration: main agent delegates upload/download to mnemospark agent, reports progress/events to user, and remains responsive.
- SQLite and JSONL troubleshooting docs published under `ops/` and validated with command examples.


## Decision lock (2026-03-16)
- Subagent runtime: use OpenClaw `subagent` runtime for mnemospark async delegation (not ACP).
- SQLite: no legacy migration/import required for this phase (fresh schema init only).
- JSONL retention: rotate at 10 MB, keep latest 10 files per stream, gzip rotated files.
- Friendly names: optional input; user-facing responses default to friendly name when available.
- Skill packaging: store/install skill from `mnemospark` repo so install is one-step.
- Ops tooling baseline required on client host: `sqlite3`, `jq`, `tail`, `grep`, `awk`, `sed`, `gzip`/`zcat`.
