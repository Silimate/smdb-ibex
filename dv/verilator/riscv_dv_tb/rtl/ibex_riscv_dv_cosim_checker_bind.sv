// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module ibex_riscv_dv_cosim_checker_bind;
  bind ibex_riscv_dv_tb ibex_riscv_dv_cosim_checker #(
      .SecureIbex,
      .ICache,
      .PMPEnable,
      .PMPGranularity,
      .PMPNumRegions,
      .MHPMCounterNum,
      .DmBaseAddr     (32'h1A110000),
      .DmAddrMask     (32'h00000FFF)
    ) u_ibex_riscv_dv_cosim_checker (
      .clk_i            (IO_CLK),
      .rst_ni           (IO_RST_N),

      .host_dmem_req    (data_req),
      .host_dmem_gnt    (data_gnt),
      .host_dmem_we     (data_we),
      .host_dmem_addr   (data_addr),
      .host_dmem_be     (data_be),
      .host_dmem_wdata  (data_wdata),

      .host_dmem_rvalid (data_rvalid),
      .host_dmem_rdata  (data_rdata),
      .host_dmem_err    (data_err)
    );
endmodule
