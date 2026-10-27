#!/usr/bin/env bash
# Generate xezim -f file for tb_cs_registers (fusesoc setup + vc2xezim).
set -euo pipefail

ibex_root="${IBEX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
out="${1:-$ibex_root/build/xezim/cs_registers/args.f}"
scripts="$ibex_root/dv/xezim/scripts"
fusesoc="$scripts/fusesoc_run.sh"

export IBEX_ROOT="$ibex_root"
build="$ibex_root/build/lowrisc_ibex_tb_cs_registers_0/sim-verilator"
vc="$build/lowrisc_ibex_tb_cs_registers_0.vc"

if [[ ! -f "$vc" ]]; then
  "$fusesoc" run --target=sim --setup lowrisc:ibex:tb_cs_registers
fi

csr_sv="$build/src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_cs_registers.sv"
wrapper="$ibex_root/dv/cs_registers/rtl/xezim_ibex_cs_registers.sv"

python3 "$scripts/vc2xezim.py" \
  "$vc" "$out" \
  --build-root "$build" \
  --ibex-root "$ibex_root" \
  -s tb_cs_registers \
  --replace-sv "$csr_sv" "$wrapper"

# The wrapper includes upstream ibex_cs_registers.sv by filename.
csr_rtl='${IBEX_ROOT}/build/lowrisc_ibex_tb_cs_registers_0/sim-verilator/src/lowrisc_ibex_ibex_core_0.1/rtl'
sed -i "1a +incdir+${csr_rtl}" "$out"

echo "Wrote $out"
