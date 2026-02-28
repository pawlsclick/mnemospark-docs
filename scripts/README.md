# Scripts

## update-company-submodules.sh

Updates the `.company` submodule (this repo) to the latest remote in **mnemospark** and **mnemospark-backend**, then **commits and pushes** the new submodule reference in each repo so they stay in sync and GitHub / fresh clones see the latest mnemospark-docs (including e.g. `cursor-dev-19-*` and `cursor-dev-20-*`).

```bash
./scripts/update-company-submodules.sh
```

The script:

1. In **mnemospark**: `git submodule update --remote .company`; if the submodule pointer changed, commits and pushes.
2. In **mnemospark-backend**: same.

If there is no change to `.company` in a repo (already at latest), it skips commit/push for that repo. Requires push access to both repos.
