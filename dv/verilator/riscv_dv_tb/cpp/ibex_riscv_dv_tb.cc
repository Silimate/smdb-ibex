// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "ibex_riscv_dv_tb.h"

#include <svdpi.h>

#include <cassert>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "Vibex_riscv_dv_tb__Syms.h"
#include "Vibex_riscv_dv_tb_ibex_riscv_dv_tb.h"
#include "cosim.h"
#include "verilator_sim_ctrl.h"

// DPI exports from ibex_riscv_dv_sparse_mem
extern "C" {
void riscv_dv_mem_write_byte(unsigned int addr, unsigned char data);
unsigned char riscv_dv_mem_read_byte(unsigned int addr);
void riscv_dv_mem_clear();
}

IbexRiscvDvTb::IbexRiscvDvTb() : cosim(nullptr) {}

int IbexRiscvDvTb::Main(int argc, char **argv) {
  bool exit_app = false;
  int ret_code = Setup(argc, argv, exit_app);
  if (exit_app) {
    return ret_code;
  }

  Run();

  if (!Finish()) {
    return 1;
  }
  return 0;
}

std::string IbexRiscvDvTb::GetIsaString() const {
  // Cast to the Verilated model type: the TOPLEVEL_NAME wrapper class is also
  // named ibex_riscv_dv_tb and would otherwise shadow the public cell pointer.
  const Vibex_riscv_dv_tb &top = top_;
  const auto *tb = top.ibex_riscv_dv_tb;
  assert(tb);

  std::string base = tb->RV32E ? "rv32e" : "rv32i";
  std::string extensions;
  if (tb->RV32M) {
    extensions += "m";
  }
  extensions += "c";

  switch (tb->RV32B) {
    case 0:  // RV32BNone
      break;
    case 1:  // RV32BBalanced
      extensions += "_Zba_Zbb_Zbs_XZbf_XZbt";
      break;
    case 2:  // RV32BOTEarlGrey
      extensions += "_Zba_Zbb_Zbc_Zbs_XZbf_XZbp_XZbr_XZbt";
      break;
    case 3:  // RV32BFull
      extensions += "_Zba_Zbb_Zbc_Zbs_XZbe_XZbf_XZbp_XZbr_XZbt";
      break;
  }

  return base + extensions;
}

void IbexRiscvDvTb::CreateCosim(bool secure_ibex, bool icache_en,
                                uint32_t pmp_num_regions,
                                uint32_t pmp_granularity,
                                uint32_t mhpm_counter_num,
                                uint32_t dm_start_addr, uint32_t dm_end_addr) {
  cosim = std::make_unique<SpikeCosim>(
      GetIsaString(), kStartPc, kStartMtvec, "riscv_dv_cosim.log", secure_ibex,
      icache_en, pmp_num_regions, pmp_granularity, mhpm_counter_num,
      dm_start_addr, dm_end_addr);

  // Sparse memory covering the full 32-bit space (same as UVM / simple_system)
  cosim->add_memory(0x00000000, 0xFFFF0000);

  // If a binary was already loaded into DUT mem, mirror it into Spike.
  if (!bin_path_.empty()) {
    std::ifstream ifs(bin_path_, std::ios::binary);
    if (ifs) {
      std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(ifs)),
                                 std::istreambuf_iterator<char>());
      CopyBinaryToCosim(bytes);
    }
  }
}

void IbexRiscvDvTb::CopyBinaryToCosim(const std::vector<uint8_t> &bytes) {
  if (!cosim) {
    return;
  }
  cosim->backdoor_write_mem(kBootAddr, bytes.size(), bytes.data());
}

bool IbexRiscvDvTb::LoadBinary(const std::string &path) {
  std::ifstream ifs(path, std::ios::binary);
  if (!ifs) {
    std::cerr << "Failed to open binary: " << path << std::endl;
    return false;
  }

  std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(ifs)),
                             std::istreambuf_iterator<char>());
  if (bytes.empty()) {
    std::cerr << "Binary is empty: " << path << std::endl;
    return false;
  }

  // Set SV scope to the sparse memory instance for DPI exports
  svScope scope =
      svGetScopeFromName("TOP.ibex_riscv_dv_tb.u_mem");
  if (!scope) {
    std::cerr << "Failed to find SV scope TOP.ibex_riscv_dv_tb.u_mem"
              << std::endl;
    return false;
  }
  svSetScope(scope);

  riscv_dv_mem_clear();
  for (size_t i = 0; i < bytes.size(); ++i) {
    riscv_dv_mem_write_byte(kBootAddr + static_cast<uint32_t>(i), bytes[i]);
  }

  std::cout << "Loaded " << bytes.size() << " bytes at 0x" << std::hex
            << kBootAddr << std::dec << " from " << path << std::endl;

  if (cosim) {
    CopyBinaryToCosim(bytes);
  }

  return true;
}

int IbexRiscvDvTb::Setup(int argc, char **argv, bool &exit_app) {
  VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();

  simctrl.SetTop(&top_, &top_.IO_CLK, &top_.IO_RST_N,
                 VerilatorSimCtrlFlags::ResetPolarityNegative);

  // Custom args: --bin=<path> and --timeout-cycles=<n>
  for (int i = 1; i < argc; ++i) {
    std::string arg(argv[i]);
    if (arg.rfind("--bin=", 0) == 0) {
      bin_path_ = arg.substr(6);
    } else if (arg.rfind("+bin=", 0) == 0) {
      bin_path_ = arg.substr(5);
    } else if (arg.rfind("--timeout-cycles=", 0) == 0) {
      timeout_cycles_ = static_cast<unsigned int>(std::stoul(arg.substr(17)));
    }
  }

  exit_app = false;
  int ret = simctrl.ParseCommandArgs(argc, argv, exit_app);
  if (exit_app) {
    return ret;
  }

  simctrl.SetTimeout(timeout_cycles_);

  if (bin_path_.empty()) {
    std::cerr << "ERROR: provide --bin=<path> or +bin=<path> to a flat "
                 "test.bin loaded at 0x80000000"
              << std::endl;
    exit_app = true;
    return 1;
  }

  // Evaluate once so the design exists, then load memory before reset release.
  // VerilatorSimCtrl will reset; load after model construction.
  if (!LoadBinary(bin_path_)) {
    exit_app = true;
    return 1;
  }

  return 0;
}

void IbexRiscvDvTb::Run() {
  VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();

  std::cout << "Simulation of Ibex (riscv-dv Verilator TB)" << std::endl
            << "==========================================" << std::endl
            << std::endl;

  simctrl.RunSimulation();
}

bool IbexRiscvDvTb::Finish() {
  VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();

  if (cosim) {
    std::cout << "Co-simulation matched " << cosim->get_insn_cnt()
              << " instructions\n";
  }

  return simctrl.WasSimulationSuccessful();
}

// Global instance for DPI create_cosim / get_spike_cosim
IbexRiscvDvTb *g_riscv_dv_tb = nullptr;

extern "C" {
void *get_spike_cosim() {
  assert(g_riscv_dv_tb);
  assert(g_riscv_dv_tb->cosim);
  return static_cast<Cosim *>(g_riscv_dv_tb->cosim.get());
}

void create_cosim(svBit secure_ibex, svBit icache_en,
                  const svBitVecVal *pmp_num_regions,
                  const svBitVecVal *pmp_granularity,
                  const svBitVecVal *mhpm_counter_num,
                  const svBitVecVal *DmStartAddr,
                  const svBitVecVal *DmEndAddr) {
  assert(g_riscv_dv_tb);
  g_riscv_dv_tb->CreateCosim(secure_ibex, icache_en, pmp_num_regions[0],
                             pmp_granularity[0], mhpm_counter_num[0],
                             DmStartAddr[0], DmEndAddr[0]);
}
}

int main(int argc, char **argv) {
  g_riscv_dv_tb = new IbexRiscvDvTb();
  int ret = g_riscv_dv_tb->Main(argc, argv);
  delete g_riscv_dv_tb;
  g_riscv_dv_tb = nullptr;
  return ret;
}
