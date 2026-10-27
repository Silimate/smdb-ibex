// Harness wrapper for xezim: tb_cs_registers instantiates ibex_cs_registers
// with only the CSR access pins connected (verilator lint_off PINMISSING).
// Verilator reads the unconnected inputs as 0; in four-state simulation they
// float z (IEEE 1800-2017 23.3.3), and csr_mtvec_init_i = z makes the mtvec
// write enable x. Pull them to 0 as Verilator does (22.9).
`unconnected_drive pull0
`include "ibex_cs_registers.sv"
`nounconnected_drive
