# Installation Guide for mnemospark

This guide provides instructions on how to install the `mnemospark` client, including its integration with the OpenClaw system.

## Prerequisites

Before proceeding, ensure you have the following installed:

- **Node.js (LTS version recommended)**: `mnemospark` is a Node.js-based application.
- **npm (Node Package Manager)**: Usually comes bundled with Node.js.
- **Git**: Required for cloning the repository or downloading source archives.
- **OpenClaw (if integrating with OpenClaw)**: Ensure your OpenClaw environment is set up.

## Installation options

There are two primary ways to install `mnemospark`: via npm (recommended for most users) or from source (for developers). When installing via npm, there are two install flows with different wallet behaviors: **default install** and **standard install**.

### Option 1: Install via npm (recommended)

You typically invoke the installer via `npx`:

```bash
npx mnemospark install --default
```

or:

```bash
npx mnemospark install --standard
```

#### Default install

- **Command**: `npx mnemospark install --default`
- **Behavior**: Creates a new Base wallet dedicated to mnemospark.
- **Wallet location**: `~/.openclaw/mnemospark/wallet/wallet.key`
- **Permissions**: The wallet key file is created with `chmod 600` so only your user can read/write it.

#### Standard install

- **Command**: `npx mnemospark install --standard`
- **Behavior**:
  - Checks for an existing legacy Blockrun wallet at `~/.openclaw/blockrun/wallet.key`.
  - If that file exists, the installer offers to **reuse** the Blockrun wallet for mnemospark.
  - If it does **not** exist (or you choose not to reuse it), the flow behaves like the **default install**, creating a new mnemospark wallet under `~/.openclaw/mnemospark/wallet/wallet.key`.

Both install flows ultimately ensure that mnemospark has a wallet configured under your `~/.openclaw` directory, either by creating a new one or by reusing an existing Blockrun wallet.

### Option 2: Install from source (for developers)

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

`mnemospark` is designed as an OpenClaw plugin. When installed, OpenClaw can detect and manage it.

The `openclaw.plugin.json` file within the `mnemospark` package exposes metadata (including the `version`) that OpenClaw uses to discover and track the plugin. When you run:

```bash
openclaw update
```

OpenClaw’s own update mechanism can detect new versions of `mnemospark` published to npm based on this metadata. No additional manual configuration is required in `mnemospark` beyond installing/updating the package itself.

## Uninstalling mnemospark

There is a dedicated uninstall script installed alongside the mnemospark OpenClaw extension.

- **Location**: `~/.openclaw/extensions/mnemospark/scripts/uninstall.sh`
- **How to run**:

  ```bash
  bash ~/.openclaw/extensions/mnemospark/scripts/uninstall.sh
  ```

This script:

- Stops the local mnemospark proxy on port 7120 (if running).
- Removes the mnemospark extension directory under `~/.openclaw/extensions/mnemospark`.
- Cleans only mnemospark-specific entries from `~/.openclaw/openclaw.json` (does not touch other plugins).
- Prints a reminder to restart OpenClaw:

  ```bash
  openclaw gateway restart
  ```

After running the script and restarting the OpenClaw gateway, mnemospark is fully uninstalled from your OpenClaw environment.

---
