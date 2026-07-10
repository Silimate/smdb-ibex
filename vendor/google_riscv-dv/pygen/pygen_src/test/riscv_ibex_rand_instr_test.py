"""
Ibex-flavoured pyflow test matching UVM riscv_rand_instr_test.

UVM testlist uses gen_test: riscv_instr_base_test (no directed streams) with
Ibex asm program gen semantics via ibex_asm_program_gen.
"""

import sys
import time
import logging
import random

sys.path.append("pygen/")

from pygen_src.test.riscv_instr_base_test import riscv_instr_base_test
from pygen_src.riscv_instr_gen_config import cfg
from pygen_src.riscv_utils import gen_config_table
from pygen_src.isa.riscv_instr import riscv_instr
from pygen_src.ibex_asm_program_gen import ibex_asm_program_gen


class riscv_ibex_rand_instr_test(riscv_instr_base_test):
    def run(self):
        # Avoid multiprocessing.Pool — hangs on macOS with pyvsc/spawn.
        for num in range(cfg.num_of_tests):
            self._run_phase(num)

    def randomize_cfg(self):
        # Bring-up counts (full UVM stress is instr_cnt=10000, num_of_sub_program=5).
        # Keep small until pyflow gen → compile → Verilator path is green.
        if cfg.instr_cnt == 10000 or cfg.instr_cnt == 0:
            cfg.instr_cnt = 200
        if cfg.num_of_sub_program == 5 or cfg.num_of_sub_program == 0:
            cfg.num_of_sub_program = 1
        cfg.require_signature_addr = 1
        if cfg.signature_addr == 0xdeadbeef:
            cfg.signature_addr = 0x8ffffffc
        cfg.randomize()
        logging.info("riscv_instr_gen_config is randomized (ibex)")
        gen_config_table()

    def apply_directed_instr(self):
        # UVM riscv_rand_instr_test uses riscv_instr_base_test — no directed streams.
        pass

    def _run_phase(self, num):
        if num == 0:
            rand_seed = str(cfg.argv.seed).split("--")[0]
        else:
            rand_seed = random.getrandbits(31)
        random.seed(int(rand_seed))
        self.randomize_cfg()
        self.asm = ibex_asm_program_gen()
        riscv_instr.create_instr_list(cfg)
        if cfg.asm_test_suffix != "":
            self.asm_file_name = "{}.{}".format(self.asm_file_name,
                                                cfg.asm_test_suffix)
        self.asm.get_directed_instr_stream()
        test_name = "{}_{}.S".format(self.asm_file_name,
                                     num + self.start_idx)
        self.apply_directed_instr()
        logging.info("All directed instruction is applied")
        self.asm.gen_program()
        self.asm.gen_test_file(test_name)
        logging.info("TEST GENERATED USING SEED VALUE = {}".format(rand_seed))
        logging.info("TEST GENERATION DONE")


start_time = time.time()
riscv_ibex_rand_instr_test().run()
end_time = time.time()
logging.info("Total execution time: {}s".format(round(end_time - start_time)))
