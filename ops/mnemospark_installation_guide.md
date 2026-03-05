# Installation Guide for mnemospark

This guide explains how to install the mnemospark **OpenClaw plugin** and, optionally, set up your wallet via the mnemospark CLI. Plugin registration is handled **only** by OpenClaw; the `npx mnemospark install` command sets up your wallet and helper scripts only.

## Prerequisites

- **Node.js (LTS version recommended)** and **npm**
- **OpenClaw**: Required for using mnemospark as a plugin (slash commands, proxy in gateway mode).
- **Git**: Only if installing from source.

## 1. Install the plugin in OpenClaw (required)

Register mnemospark with OpenClaw so slash commands and the proxy are available when the gateway runs:

```bash
openclaw plugins install mnemospark
```

Then start (or restart) the gateway:

```bash
openclaw gateway start
```

After this, `/mnemospark wallet` and `/mnemospark cloud` are available in OpenClaw. The plugin does **not** write to `~/.openclaw/extensions/` itself; only `openclaw plugins install` does that.

## 2. Wallet setup (optional)

To create or reuse a Base wallet for mnemospark (payments and storage), run the mnemospark CLI installer. This does **not** register the plugin; it only sets up your wallet and copies helper scripts (e.g. uninstall) to `~/.openclaw/mnemospark/`.

```bash
npx mnemospark install --standard
```

or, to always create a new wallet:

```bash
npx mnemospark install --default
```

If OpenClaw is on your PATH, the installer will offer to run `openclaw plugins install mnemospark` for you if the plugin is not yet installed.

### Default install

- **Command**: `npx mnemospark install --default`
- **Behavior**: Creates a new Base wallet at `~/.openclaw/mnemospark/wallet/wallet.key` (chmod 600).

### Standard install

- **Command**: `npx mnemospark install --standard`
- **Behavior**: If `~/.openclaw/blockrun/wallet.key` exists, prompts to reuse it for mnemospark; otherwise behaves like default install.

## 3. Install from source (for developers)

If you intend to contribute to `mnemospark` or need the latest development version, you can install it from source.

1. **Clone the repository:**

   ```bash
   git clone git@github.com:pawlsclick/mnemospark.git
   cd mnemospark
   ```

2. **Install dependencies:**

   ```bash
   npm install
   ```

3. **Build the project:**

   ```bash
   npm run build
   ```

4. **Link the package for local development (optional):**

   To use your local development version as a global CLI:

   ```bash
   npm link
   ```

   Or run directly from the project directory:

   ```bash
   ./bin/run <command>
   ```

## Verifying installation

After installation, verify that `mnemospark` is available and check its version:

```bash
mnemospark --version
```

You should see output similar to:

```text
mnemospark/0.1.4 <platform>-<arch> node-v<version>
```

(The exact version and platform details may differ.)

## Updating mnemospark

`mnemospark` includes built-in commands to check for and apply updates.

### Check for updates

To check if a newer version of `mnemospark` is available on npm:

```bash
mnemospark check-update
```

The output will indicate whether a new version is available.

### Install updates

To update `mnemospark` to the latest published version:

```bash
mnemospark update
```

This command will download and install the latest published version of `mnemospark` from npm.

## OpenClaw integration

Plugin registration is done **only** via `openclaw plugins install mnemospark`. Do not add `mnemospark` to `plugins.allow` or `plugins.entries` manually unless the plugin is already discoverable (i.e. installed via that command). Use `openclaw plugins list` and `openclaw plugins info mnemospark` to confirm. After installing or updating the plugin, restart the gateway.

## Uninstalling mnemospark

If you ran `npx mnemospark install`, a copy of the uninstall script was placed at `~/.openclaw/mnemospark/scripts/uninstall.sh`. Run it with:

```bash
bash ~/.openclaw/mnemospark/scripts/uninstall.sh
```

This script:

- Stops the local mnemospark proxy on port 7120 (if running).
- Removes the mnemospark extension directory under `~/.openclaw/extensions/mnemospark`.
- Cleans only mnemospark-specific entries from `~/.openclaw/openclaw.json` (does not touch other plugins).
- The script also DOES NOT remove your wallet or the directory `~/.openclaw/mnemospark`.
- Prints a reminder to restart OpenClaw:

  ```bash
  openclaw gateway restart
  ```

After running the script and restarting the OpenClaw gateway, mnemospark is fully uninstalled from your OpenClaw environment.

## Troubleshooting

### "plugin not found: mnemospark" or plugin not loading

If you see **Config invalid** with `plugins.allow: plugin not found: mnemospark`, or OpenClaw does not show mnemospark slash commands, the usual cause is a **partial or stale** plugin directory that blocks the official install. Fix it by cleaning up and reinstalling via OpenClaw only.

**Cleanup steps (run in order):**

1. **Remove mnemospark from OpenClaw config** so the gateway can start:
   - Edit `~/.openclaw/openclaw.json` and remove any `plugins.allow: ["mnemospark"]` (or the whole `plugins` block if that was the only content). Save and exit.

2. **Delete the stale plugin directory:**
   ```bash
   rm -rf ~/.openclaw/extensions/mnemospark
   ```

3. **Confirm it is gone:**
   ```bash
   ls ~/.openclaw/extensions/
   ```
   You should not see a `mnemospark` directory.

4. **Install mnemospark the official way:**
   ```bash
   openclaw plugins install mnemospark
   ```

5. **Restart the gateway:**
   ```bash
   openclaw gateway start
   ```

Plugin registration is handled **only** by `openclaw plugins install mnemospark`. The `npx mnemospark install` command sets up your wallet and optional helper scripts; it does not register the plugin with OpenClaw.

---
