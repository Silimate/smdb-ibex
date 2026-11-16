#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Run simple system co-simulation on xezim for one Ibex configuration through
# the CI scripts. With no test arguments, run the CI test list
# (ci/run-cosim-tests.sh); otherwise run one test (ci/run-cosim-test.sh).
#
# Usage: run_cosim.sh ibex_config [[--skip-pass-check] test_name test_elf]
set -euo pipefail

cfg="${1:?usage: $0 ibex_config [[--skip-pass-check] test_name test_elf]}"
shift
ibex_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
scripts="$ibex_root/examples/simple_system/xezim/scripts"
build="$ibex_root/build/xezim/simple_system_cosim/$cfg"
core=lowrisc_ibex_ibex_simple_system_cosim_0

cd "$ibex_root"
# shellcheck disable=SC2046
fusesoc --cores-root=. run --target=sim --tool=xezim --setup --build-root="$build" \
  lowrisc:ibex:ibex_simple_system_cosim $(./util/ibex_config.py "$cfg" fusesoc_opts)
IBEX_ROOT="$ibex_root" "$scripts/build_dpi.sh"

export XEZIM_ARGS_F="$build/$core/sim-xezim/$core.f"
export SSCOSIM_DPI="$ibex_root/build/xezim/simple_system_cosim/simple_system_cosim_dpi.so"
export SSCOSIM_ISA="$(./util/ibex_config.py "$cfg" spike_isa)"
export SIMPLE_SYSTEM_SIM="$scripts/xezim_simple_system.sh"

if [[ $# -eq 0 ]]; then
  exec ./ci/run-cosim-tests.sh "$cfg"
fi
exec ./ci/run-cosim-test.sh "$@"
