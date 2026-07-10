"""
Ibex-specific assembly program generator for pyflow.

Ports the key behaviours of
dv/uvm/core_ibex/riscv_dv_extension/ibex_asm_program_gen.sv:
  - debug ROM header at boot+0 / boot+8, _start at boot+0x80
  - signature handshake test_done / test_fail (not Spike tohost)
  - simple ECALL handler
  - custom CSR init (cpuctrl icache enable)
"""

from pygen_src.riscv_asm_program_gen import riscv_asm_program_gen
from pygen_src.riscv_instr_gen_config import cfg
from pygen_src.riscv_instr_pkg import pkg_ins, privileged_reg_t
from pygen_src.riscv_signature_pkg import test_result_t, signature_type_t
import pygen_src.target.ibex.riscv_core_setting as rcs  # noqa: F401


class ibex_asm_program_gen(riscv_asm_program_gen):
    def gen_program_header(self):
        # Override unsupported mstatus fields (same as SV ibex_asm_program_gen)
        cfg.mstatus_mxr = 0
        cfg.mstatus_sum = 0
        cfg.mstatus_tvm = 0
        cfg.check_misa_init_val = 0
        cfg.check_xstatus = 0

        self.instr_stream.append(".section .text")
        self.instr_stream.append(".globl _start")
        self.instr_stream.append(".option norvc")
        # 0x0 debug mode entry
        self.instr_stream.append("j debug_rom")
        self.instr_stream.append(".align 3")
        # 0x8 debug mode exception handler
        self.instr_stream.append("j debug_exception")
        # Align the start section to 0x80
        self.instr_stream.append(".align 7")
        self.instr_stream.append(".option rvc")
        self.instr_stream.append("_start:")

    def gen_test_done(self):
        # Empty: test_done / test_fail emitted from gen_init_section via gen_test_end
        pass

    def gen_test_end(self, result, instr):
        """Write TEST_RESULT handshake to signature_addr-4, then ecall."""
        test_control_addr = cfg.signature_addr - 4
        i = pkg_ins.indent
        if cfg.bare_program_mode:
            instr.append(i + "j write_tohost")
            return

        # Encode: (result << 8) | TEST_RESULT
        # TEST_RESULT enum value is 1; TEST_PASS=0, TEST_FAIL=1
        result_val = int(result)
        sig_type = int(signature_type_t.TEST_RESULT)
        gpr0 = cfg.gpr[0]
        gpr1 = cfg.gpr[1]
        instr.append(i + "li x{}, 0x{:x}".format(gpr1, test_control_addr))
        instr.append(i + "li x{}, 0x{:x}".format(gpr0, result_val))
        instr.append(i + "slli x{}, x{}, 8".format(gpr0, gpr0))
        instr.append(i + "addi x{}, x{}, 0x{:x}".format(gpr0, gpr0, sig_type))
        instr.append(i + "sw x{}, 0(x{})".format(gpr0, gpr1))
        instr.append(i + "ecall")

    def gen_ecall_handler(self, hart):
        instr = []
        self.dump_perf_stats(instr)
        self.gen_register_dump(instr)
        gpr0 = cfg.gpr[0]
        instr.append("csrr  x{}, 0x{:x}".format(gpr0, int(privileged_reg_t.MEPC)))
        instr.append("addi  x{}, x{}, 4".format(gpr0, gpr0))
        instr.append("csrw  0x{:x}, x{}".format(int(privileged_reg_t.MEPC), gpr0))
        instr.append("mret")
        self.gen_section(pkg_ins.get_label("ecall_handler", hart), instr)

    def init_custom_csr(self, instr):
        # Write 1 to cpuctrl.icache_enable (harmless if ICache=0 / illegal CSR)
        # For small config without custom CSRs, skip to avoid illegal instr traps.
        if rcs.custom_csr:
            instr.append("csrwi 0x7c0, 1")

    def setup_custom_csrs(self, hart):
        instr = []
        self.init_custom_csr(instr)
        if instr:
            self.gen_section(pkg_ins.get_label("custom_csr_init", hart), instr)

    def gen_debug_rom(self, hart):
        """Minimal debug ROM stubs (pygen base leaves this as TODO)."""
        # Labels referenced by the Ibex program header at boot+0 / boot+8.
        self.gen_section("debug_rom", ["dret"])
        self.gen_section("debug_exception", ["dret"])

    def gen_init_section(self, hart):
        super().gen_init_section(hart)

        # Jump to main when PMP is not supported (SV ibex_asm_program_gen)
        if not rcs.support_pmp:
            self.instr_stream.append(pkg_ins.indent + "j main")

        instr = []
        self.gen_test_end(test_result_t.TEST_PASS, instr)
        self.instr_stream.append(
            pkg_ins.format_string("test_done:", pkg_ins.LABEL_STR_LEN))
        self.instr_stream.extend(instr)

        instr = []
        self.gen_test_end(test_result_t.TEST_FAIL, instr)
        self.instr_stream.append(
            pkg_ins.format_string("test_fail:", pkg_ins.LABEL_STR_LEN))
        self.instr_stream.extend(instr)
