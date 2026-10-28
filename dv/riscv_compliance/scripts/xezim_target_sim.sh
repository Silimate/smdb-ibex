#!/usr/bin/env bash
# Drop-in for TARGET_SIM when running riscv-compliance against xezim.
set -euo pipefail

XEZIM="${XEZIM:-${XEZIM_BIN:-}}"
: "${XEZIM:?set XEZIM}"
: "${XEZIM_ARGS_F:?set XEZIM_ARGS_F to compliance args file}"
: "${XEZIM_OUT_DIR:?set XEZIM_OUT_DIR to per-test run directory}"
: "${IBEX_ROOT:?set IBEX_ROOT}"

export IBEX_ROOT
export PRJ_DIR="${PRJ_DIR:-$IBEX_ROOT}"
export LOWRISC_IP_DIR="${LOWRISC_IP_DIR:-$IBEX_ROOT/vendor/lowrisc_ip}"

raminit=""
term_cycles=100000
extra=()

while (($#)); do
  case "$1" in
    --raminit=*)
      raminit="${1#--raminit=}"
      ;;
    --raminit)
      shift
      raminit="${1:?}"
      ;;
    --term-after-cycles=*)
      term_cycles="${1#--term-after-cycles=}"
      ;;
    --term-after-cycles)
      shift
      term_cycles="${1:?}"
      ;;
    *)
      extra+=("$1")
      ;;
  esac
  shift
done

if [[ -z "$raminit" ]]; then
  echo "xezim_target_sim: missing --raminit" >&2
  exit 2
fi

max_time_ns=$((term_cycles * 10))
run_dir="$XEZIM_OUT_DIR/$(basename "${raminit%.*}")"
mkdir -p "$run_dir"
cd "$run_dir"

run=( "$XEZIM" --simulate --compat --error-exit
  --max-time "${max_time_ns}ns"
  -f "$XEZIM_ARGS_F"
  -gxezim_ibex_riscv_compliance/MemInitFile="$raminit"
  "${extra[@]}"
)

slot="${XEZIM_SLOT:-}"
if [[ -n "$slot" ]]; then
  "$slot" "${run[@]}"
else
  "${run[@]}"
fi
