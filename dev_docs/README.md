## Dev docs conventions

- **Cursor-dev files**:
  - Live under `dev_docs/features_cursor_dev/`.
  - Must be authored from the `dev_docs/templates/cursor-dev-template.md` template.
  - Each file represents one agent run in a single repo and includes:
    - Metadata (ID, Repo, Date, Revision, Last commit in repo).
    - Clear scope and acceptance criteria.
    - References to spec docs using both repo-relative paths and raw GitHub URLs.

- **Spec docs** (detailed design / behavior references):
  - Live under `meta_docs/` or `dev_docs/` (depending on scope).
  - Start with a metadata block: Title, Date (ISO), Revision, Related cursor-dev IDs, Repo / component.
  - Include structured sections: `## Overview`, `## Context`, `## Diagrams`, `## Details`.
  - For multi-step or stateful processes, include at least one mermaid diagram under `## Diagrams`.

- **Raw GitHub links for agents**:
  - When a cursor-dev or spec file expects an agent or tool to read another document, always include a raw GitHub URL alongside the repo-relative path.
  - Raw URL pattern for this repo:  
    `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/<path-inside-repo>`

