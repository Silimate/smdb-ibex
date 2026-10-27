#!/usr/bin/env bash
# Run fusesoc with IBEX_ROOT as the cores root.
set -euo pipefail

ibex_root="${IBEX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
if ! command -v fusesoc >/dev/null 2>&1; then
  echo "fusesoc not found in PATH" >&2
  exit 2
fi
exec fusesoc --cores-root="$ibex_root" "$@"
