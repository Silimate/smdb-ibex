# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Run the ibex_icache UVM bench with xezim.
#
# Examples:
#   make -C dv/uvm/icache SIMULATOR=xezim TEST=ibex_icache_smoke run
#   make -C dv/uvm/icache SIMULATOR=xezim run-all
#
# Optional: SIM_WRAPPER="my-slot-wrapper.sh" to run each test under a wrapper.

.SUFFIXES:
export
SHELL := bash

SIMULATOR ?= xezim
ifeq ($(SIMULATOR),xezim)
  XEZIM ?= xezim
else
  $(error Only SIMULATOR=xezim is supported in this Makefile)
endif

export IBEX_ROOT := $(abspath ../../..)
OUT ?= out/xezim
SEED ?= 1
TEST ?= ibex_icache_smoke
RUN_SCRIPT := $(IBEX_ROOT)/dv/uvm/icache/scripts/run_xezim_test.sh
SIM_WRAPPER ?=

ALL_TESTS := ibex_icache_smoke ibex_icache_passthru ibex_icache_caching \
	ibex_icache_invalidation ibex_icache_oldval ibex_icache_back_line \
	ibex_icache_many_errors ibex_icache_ecc ibex_icache_stress_all \
	ibex_icache_stress_all_with_reset

.PHONY: run run-all clean
ifeq ($(SIM_WRAPPER),)
run:
	$(RUN_SCRIPT) $(TEST) $(OUT) $(SEED)
else
run:
	$(SIM_WRAPPER) $(RUN_SCRIPT) $(TEST) $(OUT) $(SEED)
endif

run-all:
	@for t in $(ALL_TESTS); do \
	  $(MAKE) --no-print-directory TEST=$$t run || exit $$?; \
	done

clean:
	$(RM) -r $(OUT)
