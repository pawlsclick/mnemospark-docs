# Scripts

## update-company-submodules.sh

Updates the `.company` submodule (this repo) to the latest remote in **mnemospark** and **mnemospark-backend**.

```bash
./scripts/update-company-submodules.sh
```

This only updates the **working tree** in each repo. After running it, `mnemospark/.company` and `mnemospark-backend/.company` will show the latest mnemospark-docs (including e.g. `features_cursor_dev/cursor-dev-19-*` and `cursor-dev-20-*`).

### Making the update visible to others (GitHub, fresh clones)

The parent repos (mnemospark, mnemospark-backend) record which **commit** of mnemospark-docs the `.company` submodule points to. Until that recorded reference is updated and pushed, anyone viewing the repo on GitHub or cloning it will still see the **old** `.company` commit (without the newest files).

To pin the parent repos to the latest mnemospark-docs:

1. Run `./scripts/update-company-submodules.sh` (or `git submodule update --remote .company` in each repo).
2. In **mnemospark**:
   - `cd /path/to/mnemospark`
   - `git add .company`
   - `git commit -m "chore: update .company to latest mnemospark-docs"`
   - `git push`
3. In **mnemospark-backend**:
   - `cd /path/to/mnemospark-backend`
   - `git add .company`
   - `git commit -m "chore: update .company to latest mnemospark-docs"`
   - `git push`

After pushing, the submodule pointer in each parent repo will point to the latest mnemospark-docs, and `.company` on GitHub / in new clones will include the latest cursor-dev specs.
