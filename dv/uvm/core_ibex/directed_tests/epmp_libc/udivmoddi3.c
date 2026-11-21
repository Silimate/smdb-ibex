// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// The 64-bit division helpers Clang calls for syscalls.c's printf. The
// toolchain ships neither libgcc nor compiler-rt.

#include <stdint.h>

static uint64_t udivmod(uint64_t n, uint64_t d, uint64_t *rem) {
  uint64_t q = 0, r = 0;
  for (int i = 63; i >= 0; i--) {
    int carry = r >> 63;
    r = (r << 1) | ((n >> i) & 1);
    if (carry || r >= d) {
      r -= d;
      q |= (uint64_t)1 << i;
    }
  }
  *rem = r;
  return q;
}

uint64_t __udivdi3(uint64_t n, uint64_t d) {
  uint64_t r;
  return udivmod(n, d, &r);
}

uint64_t __umoddi3(uint64_t n, uint64_t d) {
  uint64_t r;
  udivmod(n, d, &r);
  return r;
}
