#!/usr/bin/env bash
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Run the RISC-V compliance test suites against the simulator in TARGET_SIM,
# reporting failures as appropriate for use in GitHub Actions.
#
# Usage: run-riscv-compliance.sh [riscv-compliance checkout]

COMPLIANCE_DIR=${1:-build/riscv-compliance}

export RISCV_PREFIX=riscv32-unknown-elf-
export RISCV_TARGET=ibex
export RISCV_DEVICE=rv32imc
fail=0
for isa in rv32i rv32im rv32imc rv32Zicsr rv32Zifencei; do
  make -C $COMPLIANCE_DIR RISCV_ISA=$isa 2>&1 | tee run.log
  if [ ${PIPESTATUS[0]} != 0 ]; then
    echo -n "::error::"
    echo "The RISC-V compliance test suite failed for $isa"

    # There's no easy way to get the test results in machine-readable
    # form to properly exclude known-failing tests. Going with an
    # approximate solution for now.
    if [ $isa == rv32i ] && grep -q 'FAIL: 4/48' run.log; then
      echo -n "::error::"
      echo "Expected failure for rv32i, see lowrisc/ibex#100 more more information."
    else
      fail=1
    fi
  fi
done
exit $fail
