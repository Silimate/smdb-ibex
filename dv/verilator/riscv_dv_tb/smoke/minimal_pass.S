# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Minimal directed program for TB bring-up (no pyflow required).
# Linked at 0x80000000; writes TEST_PASS to 0x8ffffff8 then loops.

.section .text
.globl _start
.option norvc
j debug_rom
.align 3
j debug_exception
.align 7
.option rvc
_start:
    # Write TEST_PASS handshake: (TEST_PASS<<8)|TEST_RESULT = 0x0001
    # to test-done address 0x8ffffff8
    li   t0, 0x8ffffff8
    li   t1, 0x1
    sw   t1, 0(t0)
1:  j    1b

debug_rom:
    dret
debug_exception:
    dret
