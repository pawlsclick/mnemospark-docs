# Ethereum wallet generation (mnemospark client)

**Date:** 2026-04-04  
**Revision:** rev 1  
**Milestone:** (behavior follows current mnemospark `main` / release line; not tied to a single e2e tag)  
**Repos / components:** mnemospark (OpenClaw plugin — wallet create, auto-generate on first run, signing)

## What technology is used

mnemospark generates and uses **Ethereum-style EOA (externally owned account) keys** through the **[viem](https://viem.sh)** TypeScript library (`viem` dependency in the mnemospark package).

Concretely:

- **New private keys** are created with **`generatePrivateKey()`** from **`viem/accounts`**. viem produces a cryptographically random **secp256k1** 32-byte private key, hex-encoded with a `0x` prefix (66 characters total).
- The **Ethereum address** for that key is derived with **`privateKeyToAccount()`** from **`viem/accounts`**, which applies the standard **keccak-256** public-key hash and last-20-bytes address rule used on Ethereum and EVM chains (e.g. Base).

There is **no BIP-39 mnemonic** and **no HD (BIP-32 / BIP-44) derivation** in the built-in “create wallet” or auto-generate path: the default wallet is a **single random private key** stored as raw hex in `wallet.key`.

## Where this happens in code

| Behavior | Entry points | Implementation |
|----------|--------------|----------------|
| Auto-generate on first run (no env key, no saved file) | Plugin startup via `resolveOrGenerateWalletKey()` | `src/auth.ts` — `generateAndSaveWallet()` calls `generatePrivateKey()` then `privateKeyToAccount()` |
| `/mnemospark wallet create` (optional backup of existing key) | `createMnemosparkWalletWithOptionalBackup()` | Same file — backs up existing `wallet.key` if present, then `generateAndSaveWallet()` |
| Use an existing key (not “generation”) | `MNEMOSPARK_WALLET_KEY` or `wallet.key` | `privateKeyToAccount()` only — no viem generation |

Default on-disk path for the generated key: `~/.openclaw/mnemospark/wallet/wallet.key` (see `WALLET_FILE` in `src/auth.ts`). A legacy fallback read path exists for `~/.openclaw/blockrun/wallet.key`.

## Dependency note

The mnemospark `package.json` declares **`viem`** (semver range such as `^2.39.3`); the exact resolved version follows the lockfile at install time.

---

## Spec references

- This doc: `meta_docs/ethereum-wallet-generation.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/ethereum-wallet-generation.md`
- Wallet proof / signing with the same key material: `meta_docs/wallet-proof.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/wallet-proof.md`
- Wallet slash commands and export flow: `meta_docs/wallet-and-export-process-flow.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/wallet-and-export-process-flow.md`
- Milestone overview (system context): `meta_docs/e2e-staging-milestone-2026-03-16.md`  
  Raw URL: `https://raw.githubusercontent.com/pawlsclick/mnemospark-docs/refs/heads/main/meta_docs/e2e-staging-milestone-2026-03-16.md`
