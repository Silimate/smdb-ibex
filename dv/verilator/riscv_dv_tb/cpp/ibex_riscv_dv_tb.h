// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef IBEX_RISCV_DV_TB_H_
#define IBEX_RISCV_DV_TB_H_

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "spike_cosim.h"
#include "verilated_toplevel.h"
#include "verilator_sim_ctrl.h"

class IbexRiscvDvTb {
 public:
  static constexpr uint32_t kBootAddr = 0x80000000u;
  static constexpr uint32_t kStartPc = 0x80000080u;
  static constexpr uint32_t kStartMtvec = 0x80000001u;

  IbexRiscvDvTb();
  virtual ~IbexRiscvDvTb() {}

  int Main(int argc, char **argv);

  std::unique_ptr<SpikeCosim> cosim;

  void CreateCosim(bool secure_ibex, bool icache_en, uint32_t pmp_num_regions,
                   uint32_t pmp_granularity, uint32_t mhpm_counter_num,
                   uint32_t dm_start_addr, uint32_t dm_end_addr);

  std::string GetIsaString() const;

 protected:
  ibex_riscv_dv_tb top_;
  std::string bin_path_;
  unsigned int timeout_cycles_ = 100000000;

  int Setup(int argc, char **argv, bool &exit_app);
  void Run();
  bool Finish();

  bool LoadBinary(const std::string &path);
  void CopyBinaryToCosim(const std::vector<uint8_t> &bytes);
};

#endif  // IBEX_RISCV_DV_TB_H_
