#!/usr/bin/env bash
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Write the xezim argument file for the ibex_icache UVM testbench.
#
# Usage: xezim_write_args.sh <out_file>
#
# Environment:
#   IBEX_ROOT      Ibex repository root (${IBEX_ROOT} in ibex_icache_dv.f). Defaults
#                  to three levels above this script.
#   XEZIM_UVM_DIR  UVM library for `xezim -uvm`. If unset, UVM_HOME/src is used.

set -euo pipefail

out=$1
icache_uvm=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export IBEX_ROOT=${IBEX_ROOT:-$(cd "$icache_uvm/../../.." && pwd)}
out_dir=$(dirname "$out")
mkdir -p "$out_dir"

{
  echo "-s tb"
  echo "-s ibex_icache_fcov_bind"
  echo "-timescale 1ns/1ps"
  if [ -n "${XEZIM_UVM_DIR:-}" ]; then
    echo "-uvm"
  else
    echo "+incdir+${UVM_HOME:?set XEZIM_UVM_DIR or UVM_HOME}/src"
    echo "${UVM_HOME}/src/uvm_pkg.sv"
  fi
  echo "+define+UVM"
  echo "+define+XEZIM"
  echo "-f $icache_uvm/ibex_icache_dv.f"
} > "$out"
