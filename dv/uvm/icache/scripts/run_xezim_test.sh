#!/usr/bin/env bash
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Run one ibex_icache UVM test with xezim.
#
# Usage: run_xezim_test.sh <dvsim_test_name> [out_dir] [seed]
#
# Environment: XEZIM (required), XEZIM_UVM_DIR or UVM_HOME, IBEX_ROOT (optional).

set -euo pipefail

name=${1:?}
out=${2:-out/xezim}
seed=${3:-1}

icache_uvm=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export IBEX_ROOT=${IBEX_ROOT:-$(cd "$icache_uvm/../../.." && pwd)}
xezim=${XEZIM:?set XEZIM to the xezim binary}

lookup() {
  case "$1" in
    ibex_icache_smoke) echo ibex_icache_base_test ibex_icache_base_vseq ;;
    ibex_icache_passthru) echo ibex_icache_base_test ibex_icache_passthru_vseq ;;
    ibex_icache_caching) echo ibex_icache_base_test ibex_icache_caching_vseq ;;
    ibex_icache_invalidation) echo ibex_icache_base_test ibex_icache_invalidation_vseq ;;
    ibex_icache_oldval) echo ibex_icache_oldval_test ibex_icache_oldval_vseq ;;
    ibex_icache_back_line) echo ibex_icache_base_test ibex_icache_back_line_vseq ;;
    ibex_icache_many_errors) echo ibex_icache_base_test ibex_icache_many_errors_vseq ;;
    ibex_icache_ecc) echo ibex_icache_base_test ibex_icache_ecc_vseq ;;
    ibex_icache_stress_all) echo ibex_icache_base_test ibex_icache_combo_vseq ;;
    ibex_icache_stress_all_with_reset) echo ibex_icache_base_test ibex_icache_reset_vseq ;;
    *) echo "unknown icache test $1" >&2; exit 2 ;;
  esac
}

read -r uvm_test uvm_seq <<<"$(lookup "$name")"
args_file="$out/xezim_args.f"
"$icache_uvm/scripts/xezim_write_args.sh" "$args_file"
run_dir="$out/runs/$name"
log="$out/logs/$name.log"
mkdir -p "$run_dir" "$out/logs" "$out/cache/$name"

"$xezim" --simulate --compat --max-time 20ms \
  -f "$args_file" -sv_seed "$seed" \
  +UVM_TESTNAME="$uvm_test" +UVM_TEST_SEQ="$uvm_seq" \
  +UVM_VERBOSITY=UVM_LOW +test_timeout_ns=1000000000 +enable_icache_fcov=1 \
  --cache-dir "$out/cache/$name" \
  -l "$log"
