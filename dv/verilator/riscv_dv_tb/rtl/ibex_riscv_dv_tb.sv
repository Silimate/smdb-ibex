// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef RV32M
  `define RV32M ibex_pkg::RV32MFast
`endif

`ifndef RV32B
  `define RV32B ibex_pkg::RV32BNone
`endif

`ifndef RV32ZC
  `define RV32ZC ibex_pkg::RV32Zca
`endif

`ifndef RegFile
  `define RegFile ibex_pkg::RegFileFF
`endif

/**
 * Non-UVM Verilator testbench for riscv-dv programs.
 *
 * Memory map matches the UVM core_ibex flow:
 *   Boot / binary base : 0x8000_0000
 *   Signature addr     : 0x8fff_fffc
 *   Test-done addr     : 0x8fff_fff8
 */
module ibex_riscv_dv_tb (
  input IO_CLK,
  input IO_RST_N
);

  import ibex_pkg::*;

  parameter bit                 SecureIbex               = 1'b0;
  parameter int unsigned        LockstepOffset           = 1;
  parameter bit                 ICacheScramble           = 1'b0;
  parameter bit                 PMPEnable                = 1'b0;
  parameter int unsigned        PMPGranularity           = 0;
  parameter int unsigned        PMPNumRegions            = 4;
  parameter int unsigned        MHPMCounterNum           = 0;
  parameter int unsigned        MHPMCounterWidth         = 40;
  parameter bit                 RV32E                    = 1'b0;
  parameter ibex_pkg::rv32m_e   RV32M                    = `RV32M;
  parameter ibex_pkg::rv32b_e   RV32B                    = `RV32B;
  parameter ibex_pkg::rv32zc_e  RV32ZC                   = `RV32ZC;
  parameter ibex_pkg::regfile_e RegFile                  = `RegFile;
  parameter bit                 BranchTargetALU          = 1'b0;
  parameter bit                 WritebackStage           = 1'b0;
  parameter bit                 ICache                   = 1'b0;
  parameter bit                 DbgTriggerEn             = 1'b0;
  parameter bit                 ICacheECC                = 1'b0;
  parameter bit                 ICacheTweakInfection     = 1'b0;
  parameter bit                 BranchPredictor          = 1'b0;

  // UVM-compatible addresses
  localparam logic [31:0] BootAddr       = 32'h8000_0000;
  localparam logic [31:0] SignatureAddr  = 32'h8fff_fffc;
  localparam logic [31:0] TestDoneAddr   = SignatureAddr - 32'h4;
  localparam logic [31:0] DmBaseAddr     = 32'h1A11_0000;
  localparam logic [31:0] DmAddrMask     = 32'h0000_0FFF;
  localparam logic [31:0] DmHaltAddr     = BootAddr;
  localparam logic [31:0] DmExceptionAddr = BootAddr + 32'h8;

  // Signature handshake encoding (riscv_signature_pkg)
  localparam logic [7:0] SIG_TEST_RESULT = 8'd1;
  localparam logic [7:0] SIG_TEST_PASS   = 8'd0;
  localparam logic [7:0] SIG_TEST_FAIL   = 8'd1;

  logic clk_sys, rst_sys_n;

`ifdef VERILATOR
  assign clk_sys   = IO_CLK;
  assign rst_sys_n = IO_RST_N;
`else
  initial begin
    rst_sys_n = 1'b0;
    #8 rst_sys_n = 1'b1;
  end
  initial begin
    clk_sys = 1'b0;
    forever begin
      #1 clk_sys = ~clk_sys;
    end
  end
`endif

  // -------------------------------------------------------------------------
  // Instruction / data memory buses
  // -------------------------------------------------------------------------
  logic        instr_req, instr_gnt, instr_rvalid, instr_err;
  logic [31:0] instr_addr, instr_rdata;
  logic [6:0]  instr_rdata_intg;

  logic        data_req, data_gnt, data_rvalid, data_err, data_we;
  logic [3:0]  data_be;
  logic [31:0] data_addr, data_wdata, data_rdata;
  logic [6:0]  data_rdata_intg, data_wdata_intg;

  // Stimulus (Phase 3 hooks; tied off for Phase 1)
  logic        irq_software, irq_timer, irq_external, irq_nm, debug_req;
  logic [14:0] irq_fast;
  logic        mem_err_inject;

  ibex_riscv_dv_stimulus u_stimulus (
    .clk_i          (clk_sys),
    .rst_ni         (rst_sys_n),
    .irq_software_o (irq_software),
    .irq_timer_o    (irq_timer),
    .irq_external_o (irq_external),
    .irq_fast_o     (irq_fast),
    .irq_nm_o       (irq_nm),
    .debug_req_o    (debug_req),
    .mem_err_o      (mem_err_inject)
  );

  // Scrambling key responder (Phase 2)
  logic                        scramble_req;
  logic                        scramble_key_valid;
  logic [SCRAMBLE_KEY_W-1:0]   scramble_key;
  logic [SCRAMBLE_NONCE_W-1:0] scramble_nonce;

  ibex_riscv_dv_scramble_responder #(
    .Enable(ICacheScramble)
  ) u_scramble_responder (
    .clk_i               (clk_sys),
    .rst_ni              (rst_sys_n),
    .scramble_req_i      (scramble_req),
    .scramble_key_valid_o(scramble_key_valid),
    .scramble_key_o      (scramble_key),
    .scramble_nonce_o    (scramble_nonce)
  );

  // Sparse shared memory (instr + data)
  ibex_riscv_dv_sparse_mem #(
    .SecureIbex (SecureIbex)
  ) u_mem (
    .clk_i              (clk_sys),
    .rst_ni             (rst_sys_n),

    .instr_req_i        (instr_req),
    .instr_gnt_o        (instr_gnt),
    .instr_rvalid_o     (instr_rvalid),
    .instr_addr_i       (instr_addr),
    .instr_rdata_o      (instr_rdata),
    .instr_rdata_intg_o (instr_rdata_intg),
    .instr_err_o        (instr_err),

    .data_req_i         (data_req),
    .data_gnt_o         (data_gnt),
    .data_rvalid_o      (data_rvalid),
    .data_we_i          (data_we),
    .data_be_i          (data_be),
    .data_addr_i        (data_addr),
    .data_wdata_i       (data_wdata),
    .data_rdata_o       (data_rdata),
    .data_rdata_intg_o  (data_rdata_intg),
    .data_err_o         (data_err),

    .force_err_i        (mem_err_inject)
  );

  // Signature / test-done monitor
  logic test_passed;
  logic test_failed;
  logic test_done_seen;

  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      test_passed    <= 1'b0;
      test_failed    <= 1'b0;
      test_done_seen <= 1'b0;
    end else if (data_req && data_gnt && data_we && (data_addr == TestDoneAddr)) begin
      if (data_wdata[7:0] == SIG_TEST_RESULT) begin
        test_done_seen <= 1'b1;
        if (data_wdata[15:8] == SIG_TEST_PASS) begin
          test_passed <= 1'b1;
          $display("%t: TEST_PASS written to 0x%08h", $time, TestDoneAddr);
        end else begin
          test_failed <= 1'b1;
          $display("%t: TEST_FAIL written to 0x%08h (data=0x%08h)",
                   $time, TestDoneAddr, data_wdata);
        end
      end
    end
  end

  // End simulation shortly after signature handshake
  int unsigned pass_delay_cycles;

  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      pass_delay_cycles <= 0;
    end else if (test_failed) begin
      $fatal(1, "riscv-dv test reported TEST_FAIL");
    end else if (test_passed) begin
      if (pass_delay_cycles >= 50) begin
        $display("riscv-dv test PASSED");
        $finish;
      end else begin
        pass_delay_cycles <= pass_delay_cycles + 1;
      end
    end
  end

  // Cycle timeout
  int unsigned cycle_count;
  localparam int unsigned TimeoutCycles = 100_000_000;

  always_ff @(posedge clk_sys or negedge rst_sys_n) begin
    if (!rst_sys_n) begin
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      if (cycle_count >= TimeoutCycles) begin
        $fatal(1, "TEST TIMEOUT after %0d cycles", TimeoutCycles);
      end
    end
  end

  // -------------------------------------------------------------------------
  // DUT
  // -------------------------------------------------------------------------
  ibex_top_tracing #(
      .SecureIbex           ( SecureIbex           ),
      .LockstepOffset       ( LockstepOffset       ),
      .ICacheScramble       ( ICacheScramble       ),
      .PMPEnable            ( PMPEnable            ),
      .PMPGranularity       ( PMPGranularity       ),
      .PMPNumRegions        ( PMPNumRegions        ),
      .MHPMCounterNum       ( MHPMCounterNum       ),
      .MHPMCounterWidth     ( MHPMCounterWidth     ),
      .RV32E                ( RV32E                ),
      .RV32M                ( RV32M                ),
      .RV32B                ( RV32B                ),
      .RV32ZC               ( RV32ZC               ),
      .RegFile              ( RegFile              ),
      .BranchTargetALU      ( BranchTargetALU      ),
      .ICache               ( ICache               ),
      .ICacheECC            ( ICacheECC            ),
      .ICacheTweakInfection ( ICacheTweakInfection ),
      .WritebackStage       ( WritebackStage       ),
      .BranchPredictor      ( BranchPredictor      ),
      .DbgTriggerEn         ( DbgTriggerEn         ),
      .DmBaseAddr           ( DmBaseAddr           ),
      .DmAddrMask           ( DmAddrMask           ),
      .DmHaltAddr           ( DmHaltAddr           ),
      .DmExceptionAddr      ( DmExceptionAddr      )
  ) u_top (
      .clk_i                     (clk_sys),
      .rst_ni                    (rst_sys_n),

      .test_en_i                 (1'b0),
      .scan_rst_ni               (1'b1),
      .ram_cfg_icache_tag_i      ('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}),
      .ram_cfg_icache_tag_o      (),
      .ram_cfg_icache_data_i     ('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}),
      .ram_cfg_icache_data_o     (),

      .hart_id_i                 (32'b0),
      .boot_addr_i               (BootAddr),

      .instr_req_o               (instr_req),
      .instr_gnt_i               (instr_gnt),
      .instr_rvalid_i            (instr_rvalid),
      .instr_addr_o              (instr_addr),
      .instr_rdata_i             (instr_rdata),
      .instr_rdata_intg_i        (instr_rdata_intg),
      .instr_err_i               (instr_err),

      .data_req_o                (data_req),
      .data_gnt_i                (data_gnt),
      .data_rvalid_i             (data_rvalid),
      .data_we_o                 (data_we),
      .data_be_o                 (data_be),
      .data_addr_o               (data_addr),
      .data_wdata_o              (data_wdata),
      .data_wdata_intg_o         (data_wdata_intg),
      .data_rdata_i              (data_rdata),
      .data_rdata_intg_i         (data_rdata_intg),
      .data_err_i                (data_err),

      .irq_software_i            (irq_software),
      .irq_timer_i               (irq_timer),
      .irq_external_i            (irq_external),
      .irq_fast_i                (irq_fast),
      .irq_nm_i                  (irq_nm),

      .scramble_key_valid_i      (scramble_key_valid),
      .scramble_key_i            (scramble_key),
      .scramble_nonce_i          (scramble_nonce),
      .scramble_req_o            (scramble_req),

      .debug_req_i               (debug_req),
      .crash_dump_o              (),
      .double_fault_seen_o       (),

      .fetch_enable_i            (ibex_pkg::IbexMuBiOn),
      .mcounteren_writable_i     (ibex_pkg::IbexMuBiOn),
      .alert_minor_o             (),
      .alert_major_internal_o    (),
      .alert_major_bus_o         (),
      .core_sleep_o              (),

      .lockstep_cmp_en_o         (),

      .data_req_shadow_o         (),
      .data_we_shadow_o          (),
      .data_be_shadow_o          (),
      .data_addr_shadow_o        (),
      .data_wdata_shadow_o       (),
      .data_wdata_intg_shadow_o  (),

      .instr_req_shadow_o        (),
      .instr_addr_shadow_o       ()
  );

  // Cosim checker is bound in via ibex_riscv_dv_cosim_checker_bind.sv

  // Silence unused
  logic [6:0] unused_wdata_intg;
  assign unused_wdata_intg = data_wdata_intg;

endmodule
