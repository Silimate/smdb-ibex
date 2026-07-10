"""
Ibex-specific core settings for pyflow (riscv-dv Python generator).

Mirrors dv/uvm/core_ibex/riscv_dv_extension/riscv_core_setting.tpl.sv for the
`small` (non-PMP, non-SecureIbex) bring-up configuration.
"""

import math
from pygen_src.riscv_instr_pkg import (privileged_reg_t, satp_mode_t,
                                       riscv_instr_group_t, mtvec_mode_t,
                                       privileged_mode_t)


# -----------------------------------------------------------------------------
# Processor feature configuration
# -----------------------------------------------------------------------------

XLEN = 32
SATP_MODE = satp_mode_t.BARE

# Ibex supports M and U modes
supported_privileged_mode = [privileged_mode_t.MACHINE_MODE,
                             privileged_mode_t.USER_MODE]

unsupported_instr = []

supported_isa = [riscv_instr_group_t.RV32I,
                 riscv_instr_group_t.RV32M,
                 riscv_instr_group_t.RV32C]

supported_interrupt_mode = [mtvec_mode_t.VECTORED]
max_interrupt_vector_num = 32

# small config: no PMP
support_pmp = 0
support_epmp = 0

# Debug mode support (vectors present in program header)
support_debug_mode = 1

support_umode_trap = 0
support_sfence = 0
support_unaligned_load_store = 1

NUM_FLOAT_GPR = 0
NUM_GPR = 32
NUM_VEC_GPR = 0

VECTOR_EXTENSION_ENABLE = 0
VLEN = 512
ELEN = 32
SELEN = 8
VELEN = int(math.log(ELEN) // math.log(2)) - 3
MAX_LMUL = 8

NUM_HARTS = 1

# Implemented privileged CSRs (subset matching Ibex small config)
implemented_csr = [
    privileged_reg_t.MSCRATCH,
    privileged_reg_t.MVENDORID,
    privileged_reg_t.MIMPID,
    privileged_reg_t.MARCHID,
    privileged_reg_t.MHARTID,
    privileged_reg_t.MSTATUS,
    privileged_reg_t.MISA,
    privileged_reg_t.MTVEC,
    privileged_reg_t.MEPC,
    privileged_reg_t.MCAUSE,
    privileged_reg_t.MTVAL,
    privileged_reg_t.MIE,
    privileged_reg_t.MIP,
    privileged_reg_t.MCYCLE,
    privileged_reg_t.MCYCLEH,
    privileged_reg_t.MCOUNTINHIBIT,
    privileged_reg_t.DCSR,
    privileged_reg_t.DPC,
    privileged_reg_t.DSCRATCH0,
    privileged_reg_t.DSCRATCH1,
]

# Custom CSRs empty for small (no SecureIbex+ICache). Opentitan would add
# 0x7c0 / 0x7c1; the Ibex asm generator still emits csrwi 0x7c0 when needed.
custom_csr = []
