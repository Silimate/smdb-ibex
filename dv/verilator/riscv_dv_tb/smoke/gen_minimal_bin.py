#!/usr/bin/env python3
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Emit a flat minimal_pass.bin at link address 0x80000000 (no RISC-V GCC needed)."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

BOOT = 0x80000000


def u32(x: int) -> bytes:
    return struct.pack("<I", x & 0xFFFFFFFF)


def jal(rd: int, imm: int) -> int:
    imm = imm & 0x1FFFFF
    imm20 = (imm >> 20) & 1
    imm10_1 = (imm >> 1) & 0x3FF
    imm11 = (imm >> 11) & 1
    imm19_12 = (imm >> 12) & 0xFF
    return ((imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) |
            (imm19_12 << 12) | (rd << 7) | 0x6F)


def addi(rd: int, rs1: int, imm: int) -> int:
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (rd << 7) | 0x13


def lui(rd: int, imm: int) -> int:
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | 0x37


def sw(rs2: int, rs1: int, imm: int) -> int:
    imm = imm & 0xFFF
    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (0x2 << 12) | (
        (imm & 0x1F) << 7) | 0x23


def dret() -> int:
    return 0x7B200073


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output", type=Path, required=True)
    args = parser.parse_args()

    img = bytearray(0xA0)

    def put(addr: int, word: int) -> None:
        off = addr - BOOT
        img[off:off + 4] = u32(word)

    # Header jumps (Ibex debug vectors)
    put(BOOT + 0x00, jal(0, 0x94))   # j debug_rom @ 0x94
    put(BOOT + 0x08, jal(0, 0x90))   # j debug_exception @ 0x98 (imm from 0x8)

    # _start @ 0x80: write (TEST_PASS<<8)|TEST_RESULT == 1 to 0x8ffffff8
    # 0x8ffffff8 = 0x90000000 - 8  (addi imm is sign-extended)
    put(BOOT + 0x80, lui(5, 0x90000))     # t0 = 0x90000000
    put(BOOT + 0x84, addi(5, 5, -8))      # t0 = 0x8ffffff8
    put(BOOT + 0x88, addi(6, 0, 1))       # t1 = 1
    put(BOOT + 0x8C, sw(6, 5, 0))         # sw t1, 0(t0)
    put(BOOT + 0x90, jal(0, 0))           # spin

    put(BOOT + 0x94, dret())             # debug_rom
    put(BOOT + 0x98, dret())             # debug_exception

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(bytes(img))
    print("Wrote {} ({} bytes)".format(args.output, len(img)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
