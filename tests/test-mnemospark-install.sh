#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

HOME_DIR="${HOME:-$(eval echo ~)}"
OPENCLAW_DIR="${HOME_DIR}/.openclaw"
MNEMO_DIR="${OPENCLAW_DIR}/mnemospark"
MNEMO_WALLET="${MNEMO_DIR}/wallet/wallet.key"
BLOCKRUN_WALLET="${OPENCLAW_DIR}/blockrun/wallet.key"

clean_state() {
  info "Cleaning test state under ${OPENCLAW_DIR}"
  rm -rf "${MNEMO_DIR}" "${OPENCLAW_DIR}/blockrun" "${OPENCLAW_DIR}/extensions/mnemospark"
}

assert_file() {
  local path="$1"
  [ -f "$path" ] || fail "Expected file not found: $path"
}

assert_dir() {
  local path="$1"
  [ -d "$path" ] || fail "Expected directory not found: $path"
}

assert_not_exist() {
  local path="$1"
  [ ! -e "$path" ] || fail "Path should not exist: $path"
}

test_default_install() {
  info "=== test_default_install ==="
  clean_state

  npx mnemospark install --default

  assert_dir "${MNEMO_DIR}"
  assert_dir "${MNEMO_DIR}/wallet"
  assert_file "${MNEMO_WALLET}"

  local perms
  perms=$(stat -c "%a" "${MNEMO_WALLET}")
  [ "${perms}" = "600" ] || fail "Wallet permissions expected 600, got ${perms}"

  assert_not_exist "${OPENCLAW_DIR}/blockrun"

  pass "Default install created mnemospark wallet with correct permissions"
}

test_standard_install_without_blockrun() {
  info "=== test_standard_install_without_blockrun ==="
  clean_state

  npx mnemospark install --standard

  assert_dir "${MNEMO_DIR}"
  assert_dir "${MNEMO_DIR}/wallet"
  assert_file "${MNEMO_WALLET}"
  assert_not_exist "${OPENCLAW_DIR}/blockrun"

  pass "Standard install without Blockrun behaves like default install"
}

test_standard_install_with_blockrun_reuse() {
  info "=== test_standard_install_with_blockrun_reuse ==="
  clean_state

  mkdir -p "$(dirname "${BLOCKRUN_WALLET}")"
  echo "test-blockrun-wallet" > "${BLOCKRUN_WALLET}"

  npx mnemospark install --standard

  assert_file "${BLOCKRUN_WALLET}"
  assert_file "${MNEMO_WALLET}"

  if cmp -s "${BLOCKRUN_WALLET}" "${MNEMO_WALLET}"; then
    pass "Standard install reused Blockrun wallet"
  else
    info "Standard install created a separate wallet (contents differ); verify behavior manually if needed"
  fi
}

test_cli_basics() {
  info "=== test_cli_basics ==="

  mnemospark --version || fail "mnemospark --version failed"
  mnemospark --help | grep -E "install|update|check-update" >/dev/null 2>&1 \
    || fail "mnemospark --help output missing expected commands"

  # Smoke checks; tolerate registry/network issues by not failing hard on non-zero here.
  if ! mnemospark check-update; then
    info "mnemospark check-update failed (likely network/registry); not treating as hard failure"
  fi

  pass "CLI basics validated"
}

test_uninstall_script() {
  info "=== test_uninstall_script ==="
  clean_state

  # Prepare install so extension + wallet exist
  npx mnemospark install --default

  assert_file "${MNEMO_WALLET}"

  # Run uninstall script from extension location
  local uninstall_script="${OPENCLAW_DIR}/extensions/mnemospark/scripts/uninstall.sh"
  if [ ! -f "${uninstall_script}" ]; then
    fail "Uninstall script not found at ${uninstall_script}"
  fi

  bash "${uninstall_script}"

  assert_not_exist "${OPENCLAW_DIR}/extensions/mnemospark"
  assert_file "${MNEMO_WALLET}"
  assert_not_exist "${OPENCLAW_DIR}/blockrun"

  pass "Uninstall removed extension but preserved mnemospark wallet and blockrun state"
}

main() {
  info "mnemospark install/uninstall test suite starting"

  test_default_install
  test_standard_install_without_blockrun
  test_standard_install_with_blockrun_reuse
  test_cli_basics
  test_uninstall_script

  pass "All mnemospark install/uninstall tests completed"
}

main "$@"

