#!/usr/bin/env bash
# Generate per-config xezim -f files for RISC-V compliance.
set -euo pipefail

ibex_root="${IBEX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
out_dir="${1:-$ibex_root/build/xezim/compliance/args}"
scripts="$ibex_root/dv/xezim/scripts"
fusesoc="$scripts/fusesoc_run.sh"

export IBEX_ROOT="$ibex_root"
build="$ibex_root/build/lowrisc_ibex_ibex_riscv_compliance_0.1/sim-verilator"
vc="$build/lowrisc_ibex_ibex_riscv_compliance_0.1.vc"

if [[ ! -f "$vc" ]]; then
  read -r -a fopts < <(cd "$ibex_root" && ./util/ibex_config.py small fusesoc_opts)
  "$fusesoc" run --target=sim --setup lowrisc:ibex:ibex_riscv_compliance "${fopts[@]}"
fi

upstream_sv="$build/src/lowrisc_ibex_ibex_riscv_compliance_0.1/rtl/ibex_riscv_compliance.sv"
harness_sv="$ibex_root/dv/riscv_compliance/rtl/xezim_ibex_riscv_compliance.sv"
base_f="$out_dir/base.f"

python3 "$scripts/vc2xezim.py" "$vc" "$base_f" \
  --build-root "$build" \
  --ibex-root "$ibex_root" \
  -s xezim_ibex_riscv_compliance \
  --replace-sv "$upstream_sv" "$harness_sv"

mkdir -p "$out_dir"
for cfg in small opentitan maxperf maxperf-pmp-bmbalanced maxperf-pmp-bmfull experimental-branch-predictor; do
  opts=$(cd "$ibex_root" && ./util/ibex_config.py "$cfg" fusesoc_opts)
  {
    cat "$base_f"
    echo "# config $cfg"
    for opt in $opts; do
      [[ "$opt" =~ ^--([^=]+)=(.+)$ ]] || continue
      name="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      case "$name" in
        RV32M|RV32B|RegFile) echo "-D${name}=${val}" ;;
        *) echo "-gxezim_ibex_riscv_compliance/${name}=${val}" ;;
      esac
    done
    echo "+define+RVFI=1"
  } >"$out_dir/${cfg}.f"
done

echo "Wrote $out_dir/*.f"
