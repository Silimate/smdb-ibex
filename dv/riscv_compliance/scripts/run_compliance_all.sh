#!/usr/bin/env bash
# Run RISC-V compliance for all six Ibex CI configs.
set -euo pipefail

ibex_root="${IBEX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
out_base="${XEZIM_COMPLIANCE_OUT:-$ibex_root/build/xezim/compliance/logs}"
script_dir="$(dirname "$0")"

configs=(small opentitan maxperf maxperf-pmp-bmbalanced maxperf-pmp-bmfull experimental-branch-predictor)
fail=0
for cfg in "${configs[@]}"; do
  logd="$out_base/$cfg"
  echo "=== compliance $cfg ==="
  if ! "$script_dir/run_compliance_config.sh" "$cfg" "$logd"; then
    fail=1
  fi
done
exit "$fail"
