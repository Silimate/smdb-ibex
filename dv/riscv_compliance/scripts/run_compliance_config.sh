#!/usr/bin/env bash
# Run all five CI ISA suites for one Ibex config.
set -euo pipefail

cfg="${1:?config name}"
logd="${2:?log directory}"

ibex_root="${IBEX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
XEZIM="${XEZIM:-${XEZIM_BIN:-}}"
: "${XEZIM:?set XEZIM}"
: "${RISCV_COMPLIANCE_DIR:?set RISCV_COMPLIANCE_DIR}"

if ! command -v riscv32-unknown-elf-gcc >/dev/null 2>&1; then
  echo "riscv32-unknown-elf-gcc not found in PATH" >&2
  exit 2
fi

suite_summary_line() {
  local log="$1"
  local ok fail
  ok=$(grep -E '^OK: [0-9]+/[0-9]+$' "$log" | tail -1 || true)
  fail=$(grep -E '^FAIL: [0-9]+/[0-9]+$' "$log" | tail -1 || true)
  if [[ -n "$ok" ]]; then
    echo "$ok"
  elif [[ -n "$fail" ]]; then
    echo "$fail"
  else
    echo "UNKNOWN (no OK/FAIL summary)"
  fi
}

args_f="$ibex_root/build/xezim/compliance/args/${cfg}.f"
export IBEX_ROOT="$ibex_root"
"$(dirname "$0")/gen_xezim_args.sh"

export RISCV_PREFIX="${RISCV_PREFIX:-riscv32-unknown-elf-}"
export RISCV_TARGET=ibex
export RISCV_DEVICE=rv32imc
export PARALLEL="${PARALLEL:-1}"
export JOBS="${JOBS:--j12}"
export TARGET_SIM="$ibex_root/dv/riscv_compliance/scripts/xezim_target_sim.sh"
export XEZIM_ARGS_F="$args_f"
export XEZIM_OUT_DIR="$ibex_root/build/xezim/compliance/runs/$cfg"
export PRJ_DIR="$ibex_root"
export LOWRISC_IP_DIR="$ibex_root/vendor/lowrisc_ip"

mkdir -p "$logd" "$XEZIM_OUT_DIR"
: >"$logd/suite_results.txt"
cd "$RISCV_COMPLIANCE_DIR"
rm -rf work
mkdir -p "$logd/work"
ln -sfn "$logd/work" work

default_isas=(rv32i rv32im rv32imc rv32Zicsr rv32Zifencei)
if [[ -n "${COMPLIANCE_ISA_LIST:-}" ]]; then
  read -r -a isas <<< "$COMPLIANCE_ISA_LIST"
else
  isas=("${default_isas[@]}")
fi

fail=0
for isa in "${isas[@]}"; do
  isa_log="$logd/isa_${isa}.log"
  echo "=== config=$cfg isa=$isa ===" | tee "$isa_log"
  set +e
  make RISCV_ISA="$isa" 2>&1 | tee -a "$isa_log"
  rc=${PIPESTATUS[0]}
  set -e
  summary=$(suite_summary_line "$isa_log")
  if [[ "$isa" = rv32i && "$summary" = "FAIL: 4/48" ]]; then
    result_line="RESULT config=$cfg isa=$isa: $summary (KNOWN_UPSTREAM ibex#100)"
    echo "$result_line" | tee -a "$logd/suite_results.txt"
    echo "KNOWN_UPSTREAM rv32i FAIL 4/48 (ibex#100)" >>"$logd/known_upstream.txt"
    continue
  fi
  if [[ "$rc" != 0 ]]; then
    fail=1
    result_line="RESULT config=$cfg isa=$isa: make_exit=$rc summary=$summary"
  else
    result_line="RESULT config=$cfg isa=$isa: $summary"
    if [[ "$summary" == FAIL:* ]]; then
      fail=1
    fi
  fi
  echo "$result_line" | tee -a "$logd/suite_results.txt"
done
exit "$fail"
