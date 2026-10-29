#!/usr/bin/env bash
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Run the directed simple system co-simulation tests that apply to an Ibex
# configuration, stopping at the first failure.
#
# Usage: run-cosim-tests.sh ibex_config

set -e

IBEX_CONFIG=$1

./ci/run-cosim-test.sh --skip-pass-check CoreMark examples/sw/benchmarks/coremark/coremark.elf

if ./util/ibex_config.py $IBEX_CONFIG query_fields PMPEnable | grep -q 'PMPEnable=1'; then
  ./ci/run-cosim-test.sh --skip-pass-check pmp_smoke examples/sw/simple_system/pmp_smoke_test/pmp_smoke_test.elf
else
  echo "PMP not supported on $IBEX_CONFIG, skipping pmp_smoke_test"
fi

if ./util/ibex_config.py $IBEX_CONFIG query_fields SecureIbex | grep -q 'SecureIbex=1'; then
  ./ci/run-cosim-test.sh dit_test examples/sw/simple_system/dit_test/dit_test.elf
  ./ci/run-cosim-test.sh dummy_instr_test examples/sw/simple_system/dummy_instr_test/dummy_instr_test.elf
else
  echo "Security features not supported on $IBEX_CONFIG, skipping security feature tests"
fi
