#!/usr/bin/env bash
# Run one simple-system Spike cosim test with xezim.
set -u

ibex_root="${IBEX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
cfg="${1:?config}"
prog="${2:?program basename without .vmem}"
skip_pass="${3:-0}"
max_time="${4:-2ms}"

XEZIM="${XEZIM:-${XEZIM_BIN:-}}"
: "${XEZIM:?set XEZIM}"
: "${XEZIM_INCLUDE:?set XEZIM_INCLUDE}"

script_dir="$(dirname "$0")"
out_base="${XEZIM_SSCOSIM_OUT:-$ibex_root/build/xezim/simple_system_cosim}"
run="$out_base/runs/${cfg}_${prog}"
log="$out_base/logs/${cfg}_${prog}.log"
summary="$out_base/summary.tsv"
lock="$out_base/summary.lock"

export IBEX_ROOT="$ibex_root"

vmem="${SSCOSIM_VMEM:-}"
if [[ -z "$vmem" ]]; then
  for candidate in \
    "$ibex_root/examples/sw/simple_system/${prog%.vmem}/${prog}.vmem" \
    "$ibex_root/examples/sw/simple_system/${prog}/${prog}.vmem"; do
    if [[ -f "$candidate" ]]; then
      vmem="$candidate"
      break
    fi
  done
fi

if [[ ! -f "$vmem" ]]; then
  mkdir -p "$(dirname "$summary")"
  flock "$lock" bash -c 'printf "%s\t%s\tINFRA\t-\tvmem missing (set SSCOSIM_VMEM): %s\t-\n" "$1" "$2" "$3" >>"$4"' \
    _ "$cfg" "$prog" "$vmem" "$summary"
  exit 0
fi

python3 "$script_dir/gen_xezim_args.py" "$cfg"
"$script_dir/build_dpi.sh"

args_f="$ibex_root/build/xezim/simple_system_cosim/args/${cfg}.f"
dpi_so="$ibex_root/build/xezim/simple_system_cosim/simple_system_cosim_dpi.so"

export SSCOSIM_ISA
SSCOSIM_ISA="$(python3 "$script_dir/isa_from_config.py" "$cfg")"
export SSCOSIM_VMEM="$vmem"

mkdir -p "$run" "$out_base/cache/${cfg}_${prog}" "$(dirname "$log")"
cd "$run"

wrapper=( "$XEZIM" --simulate --compat --max-time "$max_time"
  -f "$args_f"
  --dpi-lib "$dpi_so"
  -g/ibex_simple_system/SRAMInitFile="\"$vmem\""
  --cache-dir "$out_base/cache/${cfg}_${prog}"
)

set +e
slot="${XEZIM_SLOT:-}"
sim_env=( env -u XEZIM_INIT_REG -u XEZIM_INIT_ZERO -u XEZIM_INIT_X
  IBEX_ROOT="$ibex_root" PRJ_DIR="$ibex_root" LOWRISC_IP_DIR="$ibex_root/vendor/lowrisc_ip"
)
if [[ -n "$slot" ]]; then
  "${sim_env[@]}" "$slot" "${wrapper[@]}" >"$log" 2>&1
else
  "${sim_env[@]}" "${wrapper[@]}" >"$log" 2>&1
fi
rc=$?
set -e

mkdir -p "$(dirname "$summary")"
[[ -f "$summary" ]] || printf 'config\tprogram\tresult\tcosim_match\tfirst_error\tassertions\n' >"$summary"
flock "$lock" python3 "$script_dir/classify_cosim.py" \
  "$cfg" "$prog" "$skip_pass" "$log" "$run" "$rc" >>"$summary"
