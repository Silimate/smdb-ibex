"""
Copyright 2020 Google LLC
Copyright 2020 PerfectVIPs Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
"""

import logging
import random


class riscv_program:
    """Node in a call-stack tree (no instructions)."""

    def __init__(self):
        self.program_id = 0
        self.call_stack_level = 0
        self.sub_program_id = []

    def convert2string(self):
        string = "PID[{}] Lv[{}] :".format(self.program_id, self.call_stack_level)
        for i in range(len(self.sub_program_id)):
            string = "{} {}".format(string, self.sub_program_id[i])
        return string


# -----------------------------------------------------------------------------------------
# RISC-V assembly program call stack generator
#
# The call stack is generated as a tree structure to avoid dead call loop.
# Level 0:                     P0
#                           /  |  \
# Level 1:                 P1  P2  P3
#                          |     \/  \
# Level 2:                 P4    P5   P6
#                                 |
# Level 3:                        P7
#
# Rules: A program can only call the program in the next level.
#        A program can be called many times by other upper level programs.
#        A program can call the same lower level programs multiple times.
#
# Note: pyvsc constraint solving for stack_level is unreliable (same reason SV
# has a DSIM ifdef that builds levels manually). Use the DSIM-style path always.
# -----------------------------------------------------------------------------------------


class riscv_callstack_gen:
    def __init__(self):
        self.program_cnt = 10
        self.program_h = []
        self.max_stack_level = 50
        self.stack_level = []

    def init(self, program_cnt):
        self.program_cnt = program_cnt
        self.program_h = [riscv_program() for _ in range(program_cnt)]
        self.stack_level = []

    def randomize(self):
        """Build call stack levels and caller/callee links. Returns True on success."""
        try:
            self._build()
            return True
        except Exception as exc:
            logging.error("Failed to generate callstack: %s", exc)
            return False

    def _build(self):
        # DSIM-style: ascending levels without a constraint solver
        self.stack_level = [0] * self.program_cnt
        for i in range(1, self.program_cnt):
            nxt = self.stack_level[i - 1] + random.randint(0, 1)
            self.stack_level[i] = min(nxt, self.max_stack_level)

        last_level = self.stack_level[self.program_cnt - 1]
        for i in range(self.program_cnt):
            self.program_h[i].program_id = i
            self.program_h[i].call_stack_level = self.stack_level[i]
            self.program_h[i].sub_program_id = []

        for level in range(last_level):
            program_list = [j for j in range(self.program_cnt)
                            if self.stack_level[j] == level]
            next_program_list = [j for j in range(self.program_cnt)
                                 if self.stack_level[j] == level + 1]
            if not program_list or not next_program_list:
                continue

            # Every next-level program appears at least once; optionally one extra
            total_sub_program_cnt = random.randint(
                len(next_program_list), len(next_program_list) + 1)
            sub_program_id_pool = list(next_program_list)
            while len(sub_program_id_pool) < total_sub_program_cnt:
                sub_program_id_pool.append(random.choice(next_program_list))
            random.shuffle(sub_program_id_pool)

            sub_program_cnt = [0] * len(program_list)
            logging.info("%d programs @Lv%d-> %d programs at next level",
                         len(program_list), level, len(sub_program_id_pool))
            for _ in sub_program_id_pool:
                caller_id = random.randint(0, len(program_list) - 1)
                sub_program_cnt[caller_id] += 1

            idx = 0
            for j, prog_id in enumerate(program_list):
                n = sub_program_cnt[j]
                self.program_h[prog_id].sub_program_id = (
                    sub_program_id_pool[idx:idx + n])
                logging.info("%d sub programs are assigned to program[%d]",
                             n, prog_id)
                idx += n

    def print_call_stack(self, program_id_t, i, string_str):
        if len(self.program_h[i].sub_program_id) == 0:
            logging.info("%s", string_str)
        else:
            for j in range(len(self.program_h[i].sub_program_id)):
                self.print_call_stack(
                    self.program_h[i].sub_program_id[j],
                    "{} -> {}".format(string_str,
                                      self.program_h[i].sub_program_id[j]))
