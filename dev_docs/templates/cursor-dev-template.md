# Cursor Dev template

Use this template when **generating cursor-dev feature files** or **fixes** to the existing codebase. Each file is intended for **one** Cursor Agent or Cursor Cloud Agent run: the agent runs in a **single repo**, completes the scope below, and hands off via a **new branch and PR** after success.  

## File naming logic 
- If this is a new feature:  
- **Naming:** `cursor-dev-<ID>-<slug>.md`. Use a numeric ID for ordering (e.g. `01`, `02`) or a prefix + number (e.g. `auth-01`, `auth-02`). Slug = short kebab-case description.
- **Output directory:** Always write new cursor-dev files to **dev_docs/features_cursor_dev/** (in this repo: `mnemospark-docs/dev_docs/features_cursor_dev/`). Do not create cursor-dev files in other directories.

- If this is a bug fix or code change:  
- **Naming:** `fix-<ID>-<slug>.md`. Use a numeric ID for ordering (e.g. `01`, `02`) or a prefix + number (e.g. `bug-01`, `bug-02`). Slug = short kebab-case description.
- **Output directory:** Always write new fix files to **dev_docs/fix/** (in this repo: `mnemospark-docs/dev_docs/fix/`). Do not create cursor-dev files in other directories.


## Instructions for plan / author

- **One file per run:** Each file describes one completable unit of work (one agent run).  
- **Order:** Assign IDs in execution order (1, 2, 3…). In **Scope**, add "Depends on <id>" when a task requires a previous task (e.g. "Depends on cursor-dev-09", or "fix-02").
- **Repo:** Set **Repo** and the **Workspace** paragraph so the agent runs only in the correct repo. Maintain a repo mapping (e.g. in a README) that says which IDs run from which repo.
- **Handoff:** After a successful run, the agent opens a new branch from main, pushes, and creates a PR. Do not commit to main from the agent run.

Replace all `{{...}}` placeholders below. Remove optional sections that do not apply (e.g. **Start** if nothing to start, **Depends on** if no dependencies).

---

# Cursor Dev: {{TITLE}}

**ID:** {{ID}}  
**Repo:** {{REPO}}

**Workspace for Agent:** Work only in **this repo** (the repo you were started in). This repo is {{REPO}}. {{REPO_CONTEXT}} Do **not** clone, or require access to any other repository; all code and references are in this file References: {{References}}

**AWS:** When implementing or changing AWS services or resources (e.g. AWS CLI, CloudFormation/SAM templates, Lambda, API Gateway, DynamoDB), follow [AWS Best Practices](https://docs.aws.amazon.com/). The **AWS MCP Server** tool is available in this environment and should be used when working on AWS-based services and resources.

## Scope

{{SCOPE}}{{DEPENDS_ON}}

## References

{{REFERENCES}}

## Agent

- **Install (idempotent):** {{INSTALL}}
- **Start (if needed):** {{START}}
- **Secrets:** {{SECRETS}}
- **Acceptance criteria (checkboxes):**
{{ACCEPTANCE_CRITERIA}}

## Task string (optional)

{{TASK_STRING}}

---

## Placeholder reference

| Placeholder               | Description                                                    | Example                                                                                                  |
| ------------------------- | -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `{{TITLE}}`               | Short human-readable feature description                       | Lambda POST /estimate/storage                                                                            |
| `{{ID}}`                  | Unique ID for ordering and reference                           | cursor-dev-01 or auth-01                                                                                 |
| `{{REPO}}`                | Repo name the agent must run in                                | my-backend or my-client                                                                                  |
| `{{REPO_CONTEXT}}`        | Optional sentence on what lives in this repo                   | Backend features (01–10) and design patterns live in this repo.                                          |
| `{{SUBMODULE_PATH}}`      | Optional, e.g. " and `.company/`" if specs live in a submodule | and `.company/`.                                                                                         |
| `{{SPEC_PATH}}`           | Optional path to this file inside the repo                     | The spec for this feature is at `dev_docs/features/cursor-dev-01-lambda-estimate-storage.md`.   |
| `{{SCOPE}}`               | What to build in this run only (one or more paragraphs)        | Implement the Lambda for POST /estimate/storage…                                                         |
| `{{DEPENDS_ON}}`          | Optional. If needed: " Depends on {{ID}} (short description)." | Depends on cursor-dev-09 (DynamoDB).                                                                     |
| `{{REFERENCES}}`          | Bullet list of doc/spec links (relative paths, § refs)         | - [api_spec.md](../api_spec.md) §4.1                                                                     |
| `{{INSTALL}}`             | Idempotent install command(s)                                  | pip install -r requirements.txt                                                                          |
| `{{START}}`               | What to start if needed, or "None."                            | None.                                                                                                    |
| `{{SECRETS}}`             | Required env/secrets (or "None.")                              | AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION                                                     |
| `{{ACCEPTANCE_CRITERIA}}` | One line per criterion, each starting with `  - [ ] `          |   - [ ] Lambda handler accepts POST…                                                                      |
| `{{TASK_STRING}}`         | Single paragraph copy-paste prompt for the agent               | Work only in this repo. Implement… Acceptance: [ ] …                                                     |
