# Scripts

## `test_mnemospark_lite_upload.py`

End-to-end check against a deployed mnemospark-lite upload API: 402 → x402 payment → presigned PUT → complete → list/detail.

### Requirements

Python 3.11+ recommended. Install the same x402 / eth tooling you use for lite upload development (for example, align versions with `mnemospark-backend`):

```bash
pip install eth-account x402
```

### Environment

| Variable | Required | Description |
|----------|----------|-------------|
| `MNEMOSPARK_API_BASE_URL` | yes | API base (no trailing slash), e.g. `https://api.example.com` |
| `MNEMOSPARK_WALLET_KEY_PATH` | yes | File containing the payer private key (hex). **Keep local only.** |
| `MNEMOSPARK_TEST_FILE` | yes | Path to a file to upload |
| `MNEMOSPARK_TIER` | no | Default `10mb` |
| `MNEMOSPARK_CONTENT_TYPE` | no | MIME type; guessed from filename if unset |

### Run

```bash
export MNEMOSPARK_API_BASE_URL="https://…"
export MNEMOSPARK_WALLET_KEY_PATH="$HOME/.secrets/payer.key"
export MNEMOSPARK_TEST_FILE="/path/to/file.bin"
python3 scripts/test_mnemospark_lite_upload.py
```

On success, prints JSON with `uploadId`, `publicUrl`, and `downloadUrl`.
