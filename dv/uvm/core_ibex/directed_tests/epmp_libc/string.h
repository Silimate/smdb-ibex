// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Declarations for the string functions syscalls.c defines.

#include <stddef.h>

void *memcpy(void *dest, const void *src, size_t len);
void *memset(void *dest, int byte, size_t len);
size_t strlen(const char *s);
size_t strnlen(const char *s, size_t n);
int strcmp(const char *s1, const char *s2);
char *strcpy(char *dest, const char *src);
