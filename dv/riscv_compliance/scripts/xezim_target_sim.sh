#!/usr/bin/env bash
# TARGET_SIM for riscv-compliance on xezim: takes the Vibex_riscv_compliance
# options and runs ibex_riscv_compliance with the RAM loaded from MemInitFile.
set -euo pipefail

XEZIM="${XEZIM:-xezim}"
: "${XEZIM_ARGS_F:?set XEZIM_ARGS_F to the fusesoc-generated .f file}"

raminit=""
term_cycles=100000
extra=()

while (($#)); do
  case "$1" in
    --raminit=*) raminit="${1#--raminit=}" ;;
    --term-after-cycles=*) term_cycles="${1#--term-after-cycles=}" ;;
    *) extra+=("$1") ;;
  esac
  shift
done

if [[ -z "$raminit" ]]; then
  echo "xezim_target_sim: missing --raminit" >&2
  exit 2
fi

# ibex_riscv_compliance has a 10 ns clock outside Verilator.
exec "$XEZIM" --simulate --compat \
  --max-time "$((term_cycles * 10))ns" \
  -s ibex_riscv_compliance -f "$XEZIM_ARGS_F" \
  -g/ibex_riscv_compliance/MemInitFile="$raminit" \
  "${extra[@]}"
