#!/usr/bin/env bash
# Run the CI RISC-V compliance suites on xezim for one Ibex config.
# Usage: run_compliance_config.sh <ibex config> <riscv-compliance checkout>
set -euo pipefail

cfg="${1:?config name}"
compliance_dir="${2:?riscv-compliance checkout}"
ibex_root="${IBEX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
build="$ibex_root/build/xezim/compliance/$cfg"

cd "$ibex_root"
fusesoc --cores-root=. run --target=sim --tool=xezim --setup --build-root="$build" \
  lowrisc:ibex:ibex_riscv_compliance $(./util/ibex_config.py "$cfg" fusesoc_opts)

core=lowrisc_ibex_ibex_riscv_compliance_0.1
export XEZIM_ARGS_F="$build/$core/sim-xezim/$core.f"
export TARGET_SIM="$ibex_root/dv/riscv_compliance/scripts/xezim_target_sim.sh"
exec ./ci/run-riscv-compliance.sh "$compliance_dir"
