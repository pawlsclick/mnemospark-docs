#!/usr/bin/env bash
# Legacy helper script kept for reference only.
#
# The mnemospark and mnemospark-backend repos previously referenced this repo
# as a `.company` Git submodule. That submodule wiring has been removed.
# Documentation now lives only in the mnemospark-docs repository, and the
# code repos no longer need any `.company` update automation.
#
# This script is intentionally a no-op to avoid accidentally reintroducing
# submodule configuration. If you need to work with docs, clone or pull the
# mnemospark-docs repo directly:
#
#   git clone git@github.com:pawlsclick/mnemospark-docs.git
#
# and keep it up to date with `git pull`.

set -e

echo "update-company-submodules.sh: .company submodules have been removed."
echo "Docs now live only in the mnemospark-docs repo; no submodule updates needed."
