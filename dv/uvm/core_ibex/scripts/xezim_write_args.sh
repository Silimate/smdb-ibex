#!/usr/bin/env bash
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Write the xezim argument file for the core_ibex testbench.
#
# xezim parses, elaborates and simulates in one call, so the "compile" step of
# the xezim entry in yaml/rtl_simulation.yaml only builds the cosim DPI library
# and runs this script. The script gathers everything that describes the design
# (defines, parameter overrides, UVM library, file lists) into one file that the
# sim step passes with -f.
#
# Usage: xezim_write_args.sh <out_file> [compile option ...]
#
# Environment:
#   PRJ_DIR, LOWRISC_IP_DIR  Set by wrapper.mk. xezim expands ${VAR} in -f files.
#   XEZIM_UVM_DIR            UVM library for `xezim -uvm` (a release root, an src
#                            directory, or a multi-release checkout). If unset,
#                            UVM_HOME/src is used instead.

set -euo pipefail

out=$1
shift

core_ibex=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out_dir=$(dirname "$out")
mkdir -p "$out_dir"

# Pass the shared file list through, minus entries xezim cannot take:
#  - .c files: dsim and VCS build them as DPI C code; xezim would parse them as
#    SystemVerilog. They are compiled into the DPI library instead.
#  - fcov/: SystemVerilog functional-coverage code (covergroup crosses over
#    hierarchical references) that xezim does not parse. The testbench binds it
#    only when DV_FCOV_DISABLE is not defined, and this flow defines it.
filtered_list="$out_dir/ibex_dv.xezim.f"
grep -v -e '\.c$' -e '/fcov/' "$core_ibex/ibex_dv.f" > "$filtered_list"

{
  echo "-s core_ibex_tb_top"
  echo "-timescale 1ns/1ps"
  if [ -n "${XEZIM_UVM_DIR:-}" ]; then
    echo "-uvm"
  else
    echo "+incdir+${UVM_HOME:?set XEZIM_UVM_DIR or UVM_HOME}/src"
    echo "${UVM_HOME}/src/uvm_pkg.sv"
  fi
  echo "+define+UVM"
  echo "+define+XEZIM"
  echo "+define+INC_ASSERT"
  echo "+define+DV_FCOV_DISABLE"
  # Compile options: Ibex configuration (-g/... overrides and +define+...) and
  # the fixed DM_ADDR/BOOT_ADDR defines from compile_tb.py.
  for opt in "$@"; do
    echo "$opt"
  done
  echo "-f $core_ibex/ibex_dv_defines.f"
  echo "-f $filtered_list"
} > "$out"
