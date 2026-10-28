#!/usr/bin/env bash
# Run tb_cs_registers with xezim (no Verilator main).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ibex_root="${IBEX_ROOT:-$(cd "$script_dir/../../.." && pwd)}"
XEZIM="${XEZIM:-${XEZIM_BIN:-}}"
: "${XEZIM:?set XEZIM to the xezim binary}"
: "${XEZIM_INCLUDE:?set XEZIM_INCLUDE}"

run_dir="${XEZIM_RUN_DIR:-$ibex_root/build/xezim/cs_registers/run}"
args_f="$ibex_root/build/xezim/cs_registers/args.f"
dpi_so="$ibex_root/build/xezim/cs_registers/reg_dpi.so"
log="$run_dir/sim.log"

export IBEX_ROOT="$ibex_root"
export PRJ_DIR="$ibex_root"
export LOWRISC_IP_DIR="$ibex_root/vendor/lowrisc_ip"
"$script_dir/gen_xezim_args.sh" "$args_f"
"$script_dir/build_dpi.sh"

mkdir -p "$run_dir"
cd "$run_dir"

run=( "$XEZIM" --simulate --compat --error-exit --max-time 50ms
  -f "$args_f"
  --dpi-lib "$dpi_so"
  -sv_seed 1
  --cache-dir "$run_dir/cache"
)

slot="${XEZIM_SLOT:-}"
if [[ -n "$slot" ]]; then
  env -u XEZIM_INIT_REG -u XEZIM_INIT_ZERO -u XEZIM_INIT_X \
    IBEX_ROOT="$ibex_root" PRJ_DIR="$ibex_root" LOWRISC_IP_DIR="$ibex_root/vendor/lowrisc_ip" \
    "$slot" "${run[@]}" >"$log" 2>&1
else
  env -u XEZIM_INIT_REG -u XEZIM_INIT_ZERO -u XEZIM_INIT_X \
    IBEX_ROOT="$ibex_root" PRJ_DIR="$ibex_root" LOWRISC_IP_DIR="$ibex_root/vendor/lowrisc_ip" \
    "${run[@]}" >"$log" 2>&1
fi

python3 "$script_dir/result_xezim.py" "$log" | tee "$run_dir/result.txt"
