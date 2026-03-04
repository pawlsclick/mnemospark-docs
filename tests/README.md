## mnemospark / OpenClaw / ClawRouter tests

This directory contains shell scripts used to validate installation and interoperability between:

- The OpenClaw CLI
- The ClawRouter / BlockRun wallet
- The mnemospark OpenClaw plugin and CLI

All scripts are intended to run in CI-like environments as well as on local developer machines. They assume Node.js 20+, npm, and network access to install OpenClaw and ClawRouter where noted.

### Scripts overview

- **install-openclaw.sh**: Installs the OpenClaw CLI globally using npm so that the `openclaw` binary is available on `PATH`.
- **install-clawrouter.sh**: Installs or configures ClawRouter for OpenClaw (typically via the upstream installer), ensuring the OpenClaw gateway can route through ClawRouter.
- **install-mnemospark.sh**: Builds the local `mnemospark` workspace (TypeScript → `dist/`) and runs `npm link` so the `mnemospark` CLI is available globally.
- **per-job-openclaw-setup.sh**: Performs any per-job OpenClaw configuration required by CI (e.g., plugin installation, config files).
- **test-mnemospark-install.sh**: Basic installation verification for mnemospark (e.g., checks that the CLI is present and responds to `--version`).
- **test-mnemospark-openclaw-wallet.sh**: Verifies that the `mnemospark wallet` command uses `MNEMOSPARK_WALLET_KEY` (or its own wallet file) and does **not** modify `BLOCKRUN_WALLET_KEY` or the BlockRun wallet file, validating wallet environment and file separation.
- **test-mnemospark-shared-wallet.sh**: Verifies that mnemospark can read or reuse a legacy BlockRun wallet (under a test `HOME`) without modifying it, and that any mnemospark-specific files live under `~/.openclaw/mnemospark` instead of `~/.openclaw/blockrun`.
- **test-mnemospark-proxy-openclaw-coexistence.sh**: Verifies that the OpenClaw/ClawRouter gateway (port `8402`) and mnemospark proxy (default port `7120`, via `MNEMOSPARK_PROXY_PORT`) can run simultaneously without port conflicts.
- **test-mnemospark-cloud-with-clawrouter.sh**: Runs a small subset of `/mnemospark cloud` commands with the OpenClaw/ClawRouter gateway running, ensuring that mnemospark continues to use its own directories (`~/.openclaw/mnemospark/...`) and does not interfere with BlockRun wallet state.

### Recommended order of operations

When setting up a fresh environment (local or CI) to test mnemospark with OpenClaw and ClawRouter, run the scripts in this order:

1. `./install-openclaw.sh`  
   Installs the OpenClaw CLI globally.
2. `./install-clawrouter.sh`  
   Installs/configures ClawRouter for OpenClaw so the gateway can route traffic.
3. `./install-mnemospark.sh`  
   Builds the local mnemospark project and links the `mnemospark` CLI.
4. `./per-job-openclaw-setup.sh` (if used in your CI flow)  
   Applies any job-specific OpenClaw configuration.
5. `./test-mnemospark-install.sh`  
   Confirms that the mnemospark CLI is installed and responding.
6. `./test-mnemospark-openclaw-wallet.sh`  
   Confirms wallet environment variable and file separation between mnemospark and BlockRun/ClawRouter.
7. `./test-mnemospark-shared-wallet.sh`  
   Confirms that mnemospark can safely read or reuse a BlockRun wallet without modifying it, and that its own files live under `~/.openclaw/mnemospark`.
8. `./test-mnemospark-proxy-openclaw-coexistence.sh`  
   Starts the OpenClaw/ClawRouter gateway and the mnemospark proxy and verifies they listen on different ports without conflict.
9. `./test-mnemospark-cloud-with-clawrouter.sh`  
   Runs a small set of `/mnemospark cloud` commands with ClawRouter present to ensure command coexistence and path isolation.

### Notes

- The coexistence tests try to avoid modifying any real user wallets by using temporary `HOME` directories or temporary wallet key paths. In CI, these run against ephemeral homes; in local environments, prefer running them inside a container or dedicated test user if you have real BlockRun/OpenClaw wallets.
- `test-mnemospark-cloud-with-clawrouter.sh` expects `MNEMOSPARK_BACKEND_API_BASE_URL` to point at a reachable backend (real or stub). If no backend is running, the script may log a warning for `price-storage` failures but still passes if the primary coexistence checks succeed.

