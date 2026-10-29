#!/usr/bin/env bash
# CI-style simple-system cosim matrix (six configs).
#
# Build CoreMark the way ci.yml does for cosim:
#   make -C examples/sw/benchmarks/coremark SUPPRESS_PCOUNT_DUMP=1
# Spike's counters do not follow Ibex's, so the default build's counter dump
# mismatches at its first minstret read.
set -euo pipefail

ibex_root="${IBEX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
export IBEX_ROOT="$ibex_root"
script_dir="$(dirname "$0")"

configs=(small opentitan maxperf maxperf-pmp-bmbalanced maxperf-pmp-bmfull experimental-branch-predictor)

for c in "${configs[@]}"; do
  "$script_dir/run_cosim_test.sh" "$c" hello_test 1 2ms
done
for c in "${configs[@]}"; do
  "$script_dir/run_cosim_test.sh" "$c" coremark 1 60ms
done
for c in opentitan maxperf-pmp-bmbalanced maxperf-pmp-bmfull; do
  "$script_dir/run_cosim_test.sh" "$c" pmp_smoke_test 1 5ms
done
# opentitan dit_test skipped here: dbg-sscosim.md wall time exceeded 4 h on fix27/b88
"$script_dir/run_cosim_test.sh" opentitan dummy_instr_test 0 5ms

echo "Summary: $ibex_root/build/xezim/simple_system_cosim/summary.tsv"
