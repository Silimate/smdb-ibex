#!/usr/bin/env bash
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Bring-up smoke: minimal directed binary + stub cosim (no Spike/GCC/pyvsc).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
TB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$TB_DIR/out"
export PATH="${HOME}/Library/Python/3.9/bin:${PATH}"

mkdir -p "$OUT"
python3 "$TB_DIR/smoke/gen_minimal_bin.py" -o "$OUT/minimal_pass.bin"

cd "$REPO_ROOT"
fusesoc --cores-root=. run --target=sim_stub --setup --build \
  lowrisc:ibex:ibex_riscv_dv_tb \
  $(python3 util/ibex_config.py small fusesoc_opts)

SIM="$REPO_ROOT/build/lowrisc_ibex_ibex_riscv_dv_tb_0/sim_stub-verilator/Vibex_riscv_dv_tb"
"$SIM" --bin="$OUT/minimal_pass.bin" | tee "$OUT/smoke.log"
echo "SMOKE PASS"
