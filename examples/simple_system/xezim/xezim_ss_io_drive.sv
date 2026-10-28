// SPDX-License-Identifier: Apache-2.0
// Stands in for the Verilator C++ main, which drives IO_CLK and IO_RST_N.
// Without VERILATOR, ibex_simple_system generates clk_sys and rst_sys_n
// itself and leaves its top-level inputs undriven (z), so anything bound to
// IO_CLK/IO_RST_N (the cosim checker) would never see a clock edge. Under
// VERILATOR the design has clk_sys = IO_CLK and rst_sys_n = IO_RST_N; this
// restores the same equality in the other direction.

module xezim_ss_io_drive (
  input  logic clk_sys,
  input  logic rst_sys_n,
  output wire  IO_CLK,
  output wire  IO_RST_N
);
  assign IO_CLK   = clk_sys;
  assign IO_RST_N = rst_sys_n;
endmodule

bind ibex_simple_system xezim_ss_io_drive u_xezim_ss_io_drive (
  .clk_sys  (clk_sys),
  .rst_sys_n(rst_sys_n),
  .IO_CLK   (IO_CLK),
  .IO_RST_N (IO_RST_N)
);
