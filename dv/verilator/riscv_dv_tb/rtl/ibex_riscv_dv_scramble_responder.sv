// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Trivial scramble-key responder for ICacheScramble configs (Phase 2 / opentitan).
 * When Enable=0, outputs are tied off.
 */
module ibex_riscv_dv_scramble_responder #(
  parameter bit Enable = 1'b0
) (
  input  logic                              clk_i,
  input  logic                              rst_ni,
  input  logic                              scramble_req_i,
  output logic                              scramble_key_valid_o,
  output logic [ibex_pkg::SCRAMBLE_KEY_W-1:0]   scramble_key_o,
  output logic [ibex_pkg::SCRAMBLE_NONCE_W-1:0] scramble_nonce_o
);

  if (Enable) begin : g_scramble
    logic pending;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        pending             <= 1'b0;
        scramble_key_valid_o <= 1'b0;
        scramble_key_o       <= '0;
        scramble_nonce_o     <= '0;
      end else begin
        scramble_key_valid_o <= 1'b0;
        if (scramble_req_i && !pending) begin
          pending <= 1'b1;
        end else if (pending) begin
          // Respond one cycle later with a fixed key/nonce
          scramble_key_valid_o <= 1'b1;
          scramble_key_o       <= {ibex_pkg::SCRAMBLE_KEY_W{1'b1}};
          scramble_nonce_o     <= {ibex_pkg::SCRAMBLE_NONCE_W{1'b0}};
          pending              <= 1'b0;
        end
      end
    end
  end else begin : g_no_scramble
    assign scramble_key_valid_o = 1'b0;
    assign scramble_key_o       = '0;
    assign scramble_nonce_o     = '0;
  end

endmodule
