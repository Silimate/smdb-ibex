// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Phase 3 stimulus hooks for IRQ / debug / mem-error injection.
 *
 * Phase 1: all outputs tied off (matches core_ibex_base_test defaults).
 * Enable via plusargs when extending the testlist beyond riscv_rand_instr_test.
 */
module ibex_riscv_dv_stimulus (
  input  logic        clk_i,
  input  logic        rst_ni,

  output logic        irq_software_o,
  output logic        irq_timer_o,
  output logic        irq_external_o,
  output logic [14:0] irq_fast_o,
  output logic        irq_nm_o,
  output logic        debug_req_o,
  output logic        mem_err_o
);

  // Plusarg-controlled enables (default off for Phase 1)
  bit enable_irq   = 1'b0;
  bit enable_debug = 1'b0;
  bit enable_mem_err = 1'b0;

  initial begin
    void'($value$plusargs("enable_irq_stimulus=%b", enable_irq));
    void'($value$plusargs("enable_debug_stimulus=%b", enable_debug));
    void'($value$plusargs("enable_mem_err_stimulus=%b", enable_mem_err));
  end

  // Default: quiet. When enabled, provide simple periodic pulses suitable for
  // interrupt/debug stress tests (not a full UVM sequence replacement).
  int unsigned cycle;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle           <= 0;
      irq_software_o  <= 1'b0;
      irq_timer_o     <= 1'b0;
      irq_external_o  <= 1'b0;
      irq_fast_o      <= '0;
      irq_nm_o        <= 1'b0;
      debug_req_o     <= 1'b0;
      mem_err_o       <= 1'b0;
    end else begin
      cycle <= cycle + 1;

      if (enable_irq) begin
        // Pulse external IRQ every ~2000 cycles for 50 cycles
        irq_external_o <= ((cycle % 2000) < 50);
        irq_timer_o    <= ((cycle % 3000) < 30);
      end else begin
        irq_software_o <= 1'b0;
        irq_timer_o    <= 1'b0;
        irq_external_o <= 1'b0;
        irq_fast_o     <= '0;
        irq_nm_o       <= 1'b0;
      end

      if (enable_debug) begin
        debug_req_o <= ((cycle % 5000) < 20) && (cycle > 1000);
      end else begin
        debug_req_o <= 1'b0;
      end

      if (enable_mem_err) begin
        // Rare single-cycle bus errors
        mem_err_o <= ((cycle % 7919) == 0) && (cycle > 500);
      end else begin
        mem_err_o <= 1'b0;
      end
    end
  end

endmodule
