#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Stands in for Vibex_simple_system in ci/run-cosim-test.sh: takes
# --meminit=ram,<elf> and runs ibex_simple_system with the Spike cosim checker.
# The RAM loads from the .vmem next to the elf; the cosim DPI loads Spike from
# the same file (SSCOSIM_VMEM).
#
# Requires XEZIM_ARGS_F (the .f the fusesoc xezim backend wrote), SSCOSIM_DPI
# (the library build_dpi.sh wrote) and SSCOSIM_ISA. XEZIM_RUN_OPTIONS adds
# options to the xezim command line.
set -euo pipefail

: "${XEZIM_ARGS_F:?set XEZIM_ARGS_F}"
: "${SSCOSIM_DPI:?set SSCOSIM_DPI}"
: "${SSCOSIM_ISA:?set SSCOSIM_ISA}"

elf=
for arg in "$@"; do
  case "$arg" in
    --meminit=ram,*) elf="${arg#--meminit=ram,}" ;;
    *) echo "$0: unsupported argument $arg" >&2; exit 2 ;;
  esac
done
: "${elf:?usage: $0 --meminit=ram,<elf>}"

export SSCOSIM_VMEM="$(realpath "${elf%.elf}.vmem")"

# shellcheck disable=SC2086
exec "${XEZIM:-xezim}" --simulate --compat \
  -s ibex_simple_system -s ibex_simple_system_cosim_checker_bind \
  -f "$XEZIM_ARGS_F" --dpi-lib "$SSCOSIM_DPI" \
  -g/ibex_simple_system/SRAMInitFile="\"$SSCOSIM_VMEM\"" \
  ${XEZIM_RUN_OPTIONS:-}
