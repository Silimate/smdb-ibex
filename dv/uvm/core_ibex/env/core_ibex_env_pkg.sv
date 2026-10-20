// Copyright 2018 lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// ---------------------------------------------
// Core ibex environment package
// ---------------------------------------------

`include "uvm_macros.svh"
`include "dv_macros.svh"

package core_ibex_env_pkg;

  import uvm_pkg::*;
  import ibex_mem_intf_agent_pkg::*;
  import irq_agent_pkg::*;
  import ibex_cosim_agent_pkg::*;
  import push_pull_agent_pkg::*;

  // Width of the scrambling key interface's device data. Named here, rather than
  // spelled as an expression of ibex_pkg constants in each type argument, so
  // that every specialization below gets the same type key in xezim.
  localparam int unsigned ScramblingKeyDeviceDataWidth =
      ibex_pkg::SCRAMBLE_NONCE_W + ibex_pkg::SCRAMBLE_KEY_W;

  typedef push_pull_agent#(
    .DeviceDataWidth(ScramblingKeyDeviceDataWidth)
    ) scrambling_key_agent;
  typedef push_pull_agent_cfg#(
    .DeviceDataWidth(ScramblingKeyDeviceDataWidth)
    ) scrambling_key_agent_cfg;

  `include "core_ibex_vseqr.sv"
  `include "core_ibex_env_cfg.sv"
  `include "core_ibex_scoreboard.sv"
  `include "core_ibex_env.sv"

endpackage
