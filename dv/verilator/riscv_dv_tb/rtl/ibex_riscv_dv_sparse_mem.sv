// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Sparse byte-addressable memory for riscv-dv Verilator TB.
 *
 * Backed by an associative array. Binary images are loaded via DPI from C++.
 * Uninitialized reads return randomized data and (when SecureIbex=0) no error.
 */
module ibex_riscv_dv_sparse_mem #(
  parameter bit SecureIbex = 1'b0
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // Instruction port
  input  logic        instr_req_i,
  output logic        instr_gnt_o,
  output logic        instr_rvalid_o,
  input  logic [31:0] instr_addr_i,
  output logic [31:0] instr_rdata_o,
  output logic [6:0]  instr_rdata_intg_o,
  output logic        instr_err_o,

  // Data port
  input  logic        data_req_i,
  output logic        data_gnt_o,
  output logic        data_rvalid_o,
  input  logic        data_we_i,
  input  logic [3:0]  data_be_i,
  input  logic [31:0] data_addr_i,
  input  logic [31:0] data_wdata_i,
  output logic [31:0] data_rdata_o,
  output logic [6:0]  data_rdata_intg_o,
  output logic        data_err_o,

  // Optional forced bus error (Phase 3 mem-error stimulus)
  input  logic        force_err_i
);

  // Sparse byte memory
  logic [7:0] mem [bit [31:0]];

  // DPI load / backdoor API used by C++ harness
  export "DPI-C" function riscv_dv_mem_write_byte;
  export "DPI-C" function riscv_dv_mem_read_byte;
  export "DPI-C" function riscv_dv_mem_clear;

  function void riscv_dv_mem_write_byte(input int unsigned addr, input byte unsigned data);
    mem[addr] = data;
  endfunction

  function byte unsigned riscv_dv_mem_read_byte(input int unsigned addr);
    if (mem.exists(addr)) begin
      return mem[addr];
    end
    return 8'h00;
  endfunction

  function void riscv_dv_mem_clear();
    mem.delete();
  endfunction

  function automatic logic [31:0] read_word(input logic [31:0] addr);
    logic [31:0] word;
    logic [31:0] base;
    base = {addr[31:2], 2'b00};
    for (int i = 0; i < 4; i++) begin
      if (mem.exists(base + i)) begin
        word[8*i +: 8] = mem[base + i];
      end else begin
        // Uninitialized: return 0 (Spike mem is synced by C++ loader / cosim notify)
        word[8*i +: 8] = 8'h00;
      end
    end
    return word;
  endfunction

  function automatic void write_word(input logic [31:0] addr,
                                     input logic [31:0] data,
                                     input logic [3:0]  be);
    logic [31:0] base;
    base = {addr[31:2], 2'b00};
    for (int i = 0; i < 4; i++) begin
      if (be[i]) begin
        mem[base + i] = data[8*i +: 8];
      end
    end
  endfunction

  // Combinational grants (same-cycle as simple_system)
  assign instr_gnt_o = instr_req_i;
  assign data_gnt_o  = data_req_i;

  // Instruction response pipeline
  logic        instr_rvalid_q;
  logic [31:0] instr_rdata_q;
  logic        instr_err_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      instr_rvalid_q <= 1'b0;
      instr_rdata_q  <= '0;
      instr_err_q    <= 1'b0;
    end else begin
      instr_rvalid_q <= instr_req_i && instr_gnt_o;
      if (instr_req_i && instr_gnt_o) begin
        instr_rdata_q <= read_word(instr_addr_i);
        instr_err_q   <= force_err_i;
      end
    end
  end

  assign instr_rvalid_o = instr_rvalid_q;
  assign instr_rdata_o  = instr_rdata_q;
  assign instr_err_o    = instr_err_q;

  // Data response pipeline
  logic        data_rvalid_q;
  logic [31:0] data_rdata_q;
  logic        data_err_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      data_rvalid_q <= 1'b0;
      data_rdata_q  <= '0;
      data_err_q    <= 1'b0;
    end else begin
      data_rvalid_q <= data_req_i && data_gnt_o;
      if (data_req_i && data_gnt_o) begin
        if (data_we_i) begin
          write_word(data_addr_i, data_wdata_i, data_be_i);
          data_rdata_q <= '0;
        end else begin
          data_rdata_q <= read_word(data_addr_i);
        end
        data_err_q <= force_err_i;
      end
    end
  end

  assign data_rvalid_o = data_rvalid_q;
  assign data_rdata_o  = data_rdata_q;
  assign data_err_o    = data_err_q;

  // Integrity (SECDED) on responses when SecureIbex is enabled
  if (SecureIbex) begin : g_mem_rdata_ecc
    logic [31:0] unused_instr_data;
    logic [31:0] unused_data_data;

    prim_secded_inv_39_32_enc u_instr_intg (
      .data_i (instr_rdata_o),
      .data_o ({instr_rdata_intg_o, unused_instr_data})
    );

    prim_secded_inv_39_32_enc u_data_intg (
      .data_i (data_rdata_o),
      .data_o ({data_rdata_intg_o, unused_data_data})
    );
  end else begin : g_no_mem_rdata_ecc
    assign instr_rdata_intg_o = '0;
    assign data_rdata_intg_o  = '0;
  end

endmodule
